using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Gestión y seguimiento de un cliente.
///
/// El estado del cliente (Crítico, En riesgo, En seguimiento, Normal) sale de lo mismo que el reporte de Clientes
/// con caída: cuánto cayó lo comprado del 1 de enero a hoy contra el mismo tramo del año anterior. Por eso el de la
/// ficha y el del reporte coinciden siempre.
/// </summary>
public class SeguimientoClienteService : ISeguimientoClienteService
{
    private const int MaxCompras = 50;
    private const int MaxDocumentos = 30;

    /// <summary>Los productos que se muestran antes de juntar el resto en "Otros".</summary>
    private const int ProductosPrincipales = 6;

    private readonly AppDbContext _context;
    private readonly IPermisoService _permisos;
    private readonly IUsuarioActual _usuarioActual;
    private readonly IValidator<GuardarGestionRequest> _validator;
    private readonly INotificador _notificador;

    public SeguimientoClienteService(
        AppDbContext context,
        IPermisoService permisos,
        IUsuarioActual usuarioActual,
        IValidator<GuardarGestionRequest> validator,
        INotificador notificador)
    {
        _context = context;
        _permisos = permisos;
        _usuarioActual = usuarioActual;
        _validator = validator;
        _notificador = notificador;
    }

    // ------------------------------------------------------------- Catálogo y buscador

    public CatalogoSeguimientoResponse Catalogo() => new()
    {
        Tipos = TipoContacto.Todos
            .Select(t => new TipoContactoResponse { Clave = t, Etiqueta = TipoContacto.Etiqueta(t) })
            .ToList(),
        Resultados = ResultadoGestion.Catalogo
            .Select(r => new ResultadoGestionResponse { Clave = r.Clave, Etiqueta = r.Etiqueta, Tono = r.Tono, Cuando = r.Cuando })
            .ToList(),
    };

    public async Task<List<ClienteBuscadoResponse>> BuscarAsync(string? texto)
    {
        var buscado = texto?.Trim();
        if (string.IsNullOrEmpty(buscado) || buscado.Length < 2) return [];

        var (visibles, _) = await CrmConsultas.VisiblesAsync(_context, _permisos, _usuarioActual.Id);

        // "CLI00017" también sirve: el código es el id con ceros.
        int? porCodigo = buscado.StartsWith("CLI", StringComparison.OrdinalIgnoreCase)
                         && int.TryParse(buscado[3..], out var n) ? n : null;

        return await visibles
            .Where(c => c.Nombre.Contains(buscado) || c.Documento.Contains(buscado) || (porCodigo != null && c.Id == porCodigo))
            .OrderByDescending(c => c.Activo).ThenBy(c => c.Nombre)
            .Take(20)
            .Select(c => new ClienteBuscadoResponse
            {
                Id = c.Id,
                Codigo = "CLI" + c.Id.ToString().PadLeft(5, '0'),
                Nombre = c.Nombre,
                Documento = c.Documento,
                Mercado = c.Mercado != null ? c.Mercado.Nombre : null,
                Activo = c.Activo,
            })
            .ToListAsync();
    }

    // ------------------------------------------------------------- Ficha

    public async Task<FichaClienteResponse> FichaAsync(int clienteId, DateTime? desde, DateTime? hasta)
    {
        await ExigirVisibleAsync(clienteId);
        var hoy = Zona.Hoy;
        var periodo = PeriodoComparado.Crear(desde, hasta, hoy);

        var c = await _context.Clientes.AsNoTracking()
            .Where(x => x.Id == clienteId)
            .Select(x => new
            {
                x.Id, x.Nombre, x.TipoDoc, x.Documento, x.Telefono, x.Email, x.Direccion, x.DiaVisita, x.Activo, x.FechaCreacion,
                Ciudad = x.Distrito != null ? x.Distrito.Nombre : null,
                Mercado = x.Mercado != null ? x.Mercado.Nombre : null,
                Ruta = x.Ruta != null ? x.Ruta.Nombre : null,
                Vendedor = x.Vendedor != null ? x.Vendedor.Nombre : null,
                ListaPrecio = x.ListaPrecio != null ? x.ListaPrecio.Nombre : null,
            })
            .FirstAsync();

        var venta = (await CrmConsultas.VentasPorClienteAsync(_context, periodo, clienteId)).GetValueOrDefault(clienteId);
        var actual = Math.Round(venta.Actual, 2);
        var anterior = Math.Round(venta.Anterior, 2);
        var estado = EstadoCaida.Clasificar(actual, anterior);

        var categoria = (await CategorizacionConsultas.PorClienteAsync(_context)).GetValueOrDefault(clienteId);

        var ultima = await _context.NotasVenta.AsNoTracking()
            .Where(n => n.ClienteId == clienteId && n.Estado != EstadoNotaVenta.Anulada)
            .OrderByDescending(n => n.Fecha)
            .Select(n => new
            {
                n.Id, n.Numero, n.Fecha,
                Monto = n.Detalle.Where(d => !d.Anulado).Sum(d => (decimal?)(d.CantidadPresentacion * d.PrecioPresentacion)) ?? 0m,
            })
            .FirstOrDefaultAsync();

        var compras = await _context.NotasVenta.AsNoTracking()
            .CountAsync(n => n.ClienteId == clienteId && n.Estado != EstadoNotaVenta.Anulada
                             && n.Fecha >= periodo.ActualIni && n.Fecha < periodo.ActualFin);

        var gestiones = await GestionesAsync(clienteId, hoy);

        return new FichaClienteResponse
        {
            Cliente = new DatosClienteResponse
            {
                Id = c.Id,
                Codigo = $"CLI{c.Id:D5}",
                Nombre = c.Nombre,
                Tipo = c.TipoDoc == TipoDocumento.Ruc ? "Empresa" : "Persona",
                TipoDoc = c.TipoDoc,
                Documento = c.Documento,
                Telefono = c.Telefono,
                Email = c.Email,
                Direccion = c.Direccion,
                Ciudad = c.Ciudad,
                Mercado = c.Mercado,
                Ruta = c.Ruta,
                Vendedor = c.Vendedor,
                ListaPrecio = c.ListaPrecio,
                DiaVisita = c.DiaVisita,
                CategoriaCodigo = categoria?.Codigo,
                Categoria = categoria?.Nombre,
                CategoriaColor = categoria?.Color,
                Activo = c.Activo,
                FechaAlta = Zona.DiaDe(c.FechaCreacion),
                Estado = new EstadoClienteResponse { Clave = estado, Etiqueta = EstadoCaida.Etiqueta(estado) },
            },
            Kpis = new KpisClienteResponse
            {
                DiasSinComprar = ultima is null ? null : Math.Max(0, (int)(hoy - Zona.DiaDe(ultima.Fecha)).TotalDays),
                UltimaCompra = ultima is null
                    ? null
                    : new UltimaCompraResponse { Id = ultima.Id, Fecha = ultima.Fecha, Documento = ultima.Numero, Monto = Math.Round(ultima.Monto, 2) },
                SaldoPorCobrar = (await CrmConsultas.SaldosPorCobrarAsync(_context, clienteId)).GetValueOrDefault(clienteId),
            },
            Periodo = new PeriodoClienteResponse
            {
                Desde = periodo.Desde,
                Hasta = periodo.Hasta,
                Etiqueta = CrmConsultas.Etiqueta(periodo.Desde, periodo.Hasta),
                EtiquetaAnterior = CrmConsultas.Etiqueta(periodo.AnteriorDesde, periodo.AnteriorHasta),
                Ventas = actual,
                Compras = compras,
                TicketPromedio = compras > 0 ? Math.Round(actual / compras, 2) : 0m,
                VentasAnterior = anterior,
                Variacion = actual - anterior,
                CaidaPct = EstadoCaida.CaidaPct(actual, anterior),
            },
            UltimaGestion = gestiones.Items.FirstOrDefault(),
            ProximaGestion = gestiones.ProximaGestion,
            ProductosPrincipales = await PrincipalesAsync(clienteId, periodo),
            Meses = await MesesAsync(clienteId, hoy),
        };
    }

    /// <summary>Los productos del año con más compras, y el resto junto en "Otros". El % es del total del tramo.</summary>
    private async Task<List<ProductoPrincipalResponse>> PrincipalesAsync(int clienteId, PeriodoComparado p)
    {
        var ini = p.ActualIni;
        var fin = p.ActualFin;

        var filas = await _context.NotaVentaDetalles.AsNoTracking()
            .Where(d => !d.Anulado
                        && d.NotaVenta!.ClienteId == clienteId
                        && d.NotaVenta.Estado != EstadoNotaVenta.Anulada
                        && d.NotaVenta.Fecha >= ini && d.NotaVenta.Fecha < fin)
            .GroupBy(d => d.ProductoId)
            .Select(g => new
            {
                Codigo = g.Max(d => d.Producto!.Codigo),
                Producto = g.Max(d => d.Producto!.Nombre),
                Monto = g.Sum(d => d.CantidadPresentacion * d.PrecioPresentacion),
            })
            .ToListAsync();

        var total = filas.Sum(f => f.Monto);
        if (total <= 0) return [];

        var ordenadas = filas.OrderByDescending(f => f.Monto).ToList();
        var lista = ordenadas.Take(ProductosPrincipales)
            .Select(f => new ProductoPrincipalResponse
            {
                Producto = f.Producto ?? string.Empty,
                Codigo = f.Codigo,
                Monto = Math.Round(f.Monto, 2),
                Porcentaje = Math.Round(f.Monto / total * 100m, 1),
            })
            .ToList();

        var resto = ordenadas.Skip(ProductosPrincipales).Sum(f => f.Monto);
        if (resto > 0)
            lista.Add(new ProductoPrincipalResponse { Producto = "Otros", Monto = Math.Round(resto, 2), Porcentaje = Math.Round(resto / total * 100m, 1) });

        return lista;
    }

    /// <summary>
    /// Lo comprado por mes en los últimos 24 meses: las líneas vigentes menos lo recogido. Se agrupa por el mes de
    /// Perú (no el de UTC): una venta de las 9 de la noche del último día del mes es de ese mes.
    /// </summary>
    private async Task<List<MesClienteResponse>> MesesAsync(int clienteId, DateTime hoy)
    {
        var primero = new DateTime(hoy.Year, hoy.Month, 1).AddMonths(-23);
        var inicio = Zona.AUtc(primero);

        var lineas = await _context.NotaVentaDetalles.AsNoTracking()
            .Where(d => !d.Anulado
                        && d.NotaVenta!.ClienteId == clienteId
                        && d.NotaVenta.Estado != EstadoNotaVenta.Anulada
                        && d.NotaVenta.Fecha >= inicio)
            .Select(d => new { d.NotaVenta!.Fecha, Importe = d.CantidadPresentacion * d.PrecioPresentacion })
            .ToListAsync();

        var recojos = await _context.RecojosVenta.AsNoTracking()
            .Where(r => r.Estado != EstadoRecojo.Anulado
                        && r.NotaVenta!.ClienteId == clienteId
                        && r.NotaVenta.Estado != EstadoNotaVenta.Anulada
                        && r.NotaVenta.Fecha >= inicio)
            .Select(r => new { r.NotaVenta!.Fecha, r.Importe })
            .ToListAsync();

        static DateTime MesDe(DateTime utc) { var d = Zona.DiaDe(utc); return new DateTime(d.Year, d.Month, 1); }

        var porMes = lineas.GroupBy(l => MesDe(l.Fecha)).ToDictionary(g => g.Key, g => g.Sum(l => l.Importe));
        foreach (var r in recojos)
            porMes[MesDe(r.Fecha)] = porMes.GetValueOrDefault(MesDe(r.Fecha)) - r.Importe;

        return Enumerable.Range(0, 24)
            .Select(i => primero.AddMonths(i))
            .Select(mes => new MesClienteResponse { Mes = mes, Importe = Math.Round(Math.Max(0m, porMes.GetValueOrDefault(mes)), 2) })
            .ToList();
    }

    // ------------------------------------------------------------- Gestiones

    public async Task<GestionesClienteResponse> GestionesAsync(int clienteId)
    {
        await ExigirVisibleAsync(clienteId);
        return await GestionesAsync(clienteId, Zona.Hoy);
    }

    private async Task<GestionesClienteResponse> GestionesAsync(int clienteId, DateTime hoy)
    {
        var ahora = DateTime.UtcNow;

        var filas = await _context.GestionesCliente.AsNoTracking()
            .Where(g => g.ClienteId == clienteId)
            .OrderByDescending(g => g.Fecha).ThenByDescending(g => g.Id)
            .Select(g => new
            {
                Gestion = g,
                Usuario = g.Usuario != null ? g.Usuario.Nombre : null,
            })
            .ToListAsync();

        var items = filas.Select(f => Mapear(f.Gestion, f.Usuario, ahora)).ToList();
        var desdeAnio = new DateTime(hoy.Year, 1, 1);

        return new GestionesClienteResponse
        {
            Items = items,
            ProximaGestion = items
                .Where(g => g.SeguimientoEstado == EstadoSeguimiento.Programado && g.ProximoSeguimiento != null)
                .OrderBy(g => g.ProximoSeguimiento)
                .FirstOrDefault(),
            TotalAnio = filas.Count(f => f.Gestion.Fecha >= Zona.AUtc(desdeAnio)),
            DesdeAnio = desdeAnio,
        };
    }

    public async Task<GestionResponse> RegistrarAsync(int clienteId, GuardarGestionRequest request)
    {
        await _validator.ValidateAndThrowAsync(request);
        await ExigirVisibleAsync(clienteId);

        var proximo = ProximoEnUtc(request.ProximoSeguimiento);

        // Esta gestión ES el contacto que estaba programado: se da por cumplido. Un cliente tiene uno solo a la vez.
        await CumplirProgramadosAsync(clienteId, exceptoId: null);

        var gestion = new GestionCliente
        {
            ClienteId = clienteId,
            TipoContacto = request.TipoContacto,
            Resultado = request.Resultado,
            Comentario = LimpiarTexto(request.Comentario),
            UsuarioId = _usuarioActual.Id,
        };
        AplicarProximo(gestion, proximo, request);

        _context.GestionesCliente.Add(gestion);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("seguimientos", "creado", new { clienteId, id = gestion.Id });
        return await UnaAsync(gestion.Id);
    }

    public async Task<GestionResponse> ActualizarAsync(int gestionId, GuardarGestionRequest request)
    {
        await _validator.ValidateAndThrowAsync(request);

        var gestion = await _context.GestionesCliente.FirstOrDefaultAsync(g => g.Id == gestionId)
            ?? throw new NotFoundException("Gestión no encontrada");
        await ExigirVisibleAsync(gestion.ClienteId);

        gestion.TipoContacto = request.TipoContacto;
        gestion.Resultado = request.Resultado;
        gestion.Comentario = LimpiarTexto(request.Comentario);

        if (gestion.SeguimientoEstado == EstadoSeguimiento.Cumplido)
        {
            // Ya se cumplió: es historia. Solo se retoca lo que se iba a hacer.
            if (gestion.ProximoSeguimiento is not null) gestion.ProximaAccion = LimpiarTexto(request.ProximaAccion);
        }
        else
        {
            var proximo = ProximoEnUtc(request.ProximoSeguimiento);
            if (proximo is not null) await CumplirProgramadosAsync(gestion.ClienteId, exceptoId: gestion.Id);
            AplicarProximo(gestion, proximo, request);
        }

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("seguimientos", "actualizado", new { clienteId = gestion.ClienteId, id = gestion.Id });
        return await UnaAsync(gestion.Id);
    }

    public async Task<GestionResponse> ReprogramarAsync(int gestionId, ReprogramarGestionRequest request)
    {
        var gestion = await _context.GestionesCliente.FirstOrDefaultAsync(g => g.Id == gestionId)
            ?? throw new NotFoundException("Gestión no encontrada");
        await ExigirVisibleAsync(gestion.ClienteId);

        if (gestion.SeguimientoEstado != EstadoSeguimiento.Programado)
            throw new BadRequestException("Solo se puede reprogramar un contacto que sigue programado");

        gestion.ProximoSeguimiento = ProximoEnUtc(request.ProximoSeguimiento);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("seguimientos", "actualizado", new { clienteId = gestion.ClienteId, id = gestion.Id });
        return await UnaAsync(gestion.Id);
    }

    /// <summary>El día y la hora (de Perú) pasados a UTC. No puede ser un día que ya pasó.</summary>
    private static DateTime? ProximoEnUtc(DateTime? local)
    {
        if (local is not DateTime dia) return null;
        if (dia.Date < Zona.Hoy)
            throw new BadRequestException("El día del próximo seguimiento no puede ser anterior a hoy");
        return Zona.AUtc(dia);
    }

    private static void AplicarProximo(GestionCliente gestion, DateTime? proximoUtc, GuardarGestionRequest request)
    {
        if (proximoUtc is null)
        {
            gestion.ProximoSeguimiento = null;
            gestion.ProximoTipoContacto = null;
            gestion.ProximaAccion = null;
            gestion.SeguimientoEstado = null;
            return;
        }

        gestion.ProximoSeguimiento = proximoUtc;
        gestion.ProximoTipoContacto = request.ProximoTipoContacto ?? request.TipoContacto;
        gestion.ProximaAccion = LimpiarTexto(request.ProximaAccion);
        gestion.SeguimientoEstado = EstadoSeguimiento.Programado;
    }

    private async Task CumplirProgramadosAsync(int clienteId, int? exceptoId)
    {
        var previos = await _context.GestionesCliente
            .Where(g => g.ClienteId == clienteId
                        && g.SeguimientoEstado == EstadoSeguimiento.Programado
                        && (exceptoId == null || g.Id != exceptoId))
            .ToListAsync();
        foreach (var g in previos) g.SeguimientoEstado = EstadoSeguimiento.Cumplido;
    }

    private static string? LimpiarTexto(string? texto) => string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private async Task<GestionResponse> UnaAsync(int id)
    {
        var fila = await _context.GestionesCliente.AsNoTracking()
            .Where(g => g.Id == id)
            .Select(g => new { Gestion = g, Usuario = g.Usuario != null ? g.Usuario.Nombre : null })
            .FirstAsync();
        return Mapear(fila.Gestion, fila.Usuario, DateTime.UtcNow);
    }

    private static GestionResponse Mapear(GestionCliente g, string? usuario, DateTime ahora)
    {
        var (etiqueta, tono) = ResultadoGestion.De(g.Resultado);
        var programado = g.SeguimientoEstado == EstadoSeguimiento.Programado;

        return new GestionResponse
        {
            Id = g.Id,
            ClienteId = g.ClienteId,
            Fecha = g.Fecha,
            TipoContacto = g.TipoContacto,
            TipoEtiqueta = TipoContacto.Etiqueta(g.TipoContacto),
            Resultado = g.Resultado,
            ResultadoEtiqueta = etiqueta,
            Tono = tono,
            Comentario = g.Comentario,
            RegistradoPor = usuario,
            ProximoSeguimiento = g.ProximoSeguimiento,
            ProximoTipoContacto = g.ProximoTipoContacto ?? (g.ProximoSeguimiento is null ? null : g.TipoContacto),
            ProximoTipoEtiqueta = g.ProximoSeguimiento is null
                ? null
                : TipoContacto.Etiqueta(g.ProximoTipoContacto ?? g.TipoContacto),
            ProximaAccion = g.ProximaAccion,
            SeguimientoEstado = g.SeguimientoEstado,
            Vencida = programado && g.ProximoSeguimiento < ahora,
        };
    }

    // ------------------------------------------------------------- Compras y documentos

    public async Task<ComprasClienteResponse> ComprasAsync(int clienteId, DateTime? desde, DateTime? hasta)
    {
        await ExigirVisibleAsync(clienteId);
        var periodo = PeriodoComparado.Crear(desde, hasta, Zona.Hoy);

        var notas = await _context.NotasVenta.AsNoTracking()
            .Where(n => n.ClienteId == clienteId)
            .OrderByDescending(n => n.Fecha)
            .Take(MaxCompras)
            .Select(n => new
            {
                n.Id, n.Numero, n.Fecha, n.Estado, n.FormaPago,
                Vendedor = n.Usuario != null ? n.Usuario.Nombre : null,
                Total = n.Detalle.Where(d => !d.Anulado).Sum(d => (decimal?)(d.CantidadPresentacion * d.PrecioPresentacion)) ?? 0m,
                Pagado = n.Pagos.Where(p => !p.Anulado).Sum(p => (decimal?)p.Monto) ?? 0m,
            })
            .ToListAsync();

        var venta = (await CrmConsultas.VentasPorClienteAsync(_context, periodo, clienteId)).GetValueOrDefault(clienteId);

        return new ComprasClienteResponse
        {
            Periodo = new PeriodoClienteResponse
            {
                Desde = periodo.Desde,
                Hasta = periodo.Hasta,
                Etiqueta = CrmConsultas.Etiqueta(periodo.Desde, periodo.Hasta),
                EtiquetaAnterior = CrmConsultas.Etiqueta(periodo.AnteriorDesde, periodo.AnteriorHasta),
                Ventas = Math.Round(venta.Actual, 2),
                VentasAnterior = Math.Round(venta.Anterior, 2),
                Variacion = Math.Round(venta.Actual - venta.Anterior, 2),
                CaidaPct = EstadoCaida.CaidaPct(venta.Actual, venta.Anterior),
            },
            Ventas = notas.Select(n => new CompraClienteResponse
            {
                NotaVentaId = n.Id,
                Numero = n.Numero,
                Fecha = n.Fecha,
                Estado = n.Estado,
                FormaPago = n.FormaPago,
                Vendedor = n.Vendedor,
                Total = Math.Round(n.Total, 2),
                Pagado = Math.Round(n.Pagado, 2),
                // Solo una venta a crédito vigente deja deuda: al contado o anulada no se debe nada.
                Saldo = n.Estado == EstadoNotaVenta.Confirmada && n.FormaPago == FormaPagoVenta.Credito
                    ? Math.Max(0m, Math.Round(n.Total - n.Pagado, 2))
                    : 0m,
            }).ToList(),
            Productos = await CaidaService.ProductosDelClienteAsync(_context, clienteId, periodo),
        };
    }

    public async Task<DocumentosClienteResponse> DocumentosAsync(int clienteId)
    {
        await ExigirVisibleAsync(clienteId);

        var pedidos = await _context.Pedidos.AsNoTracking()
            .Where(p => p.ClienteId == clienteId)
            .OrderByDescending(p => p.Fecha)
            .Take(MaxDocumentos)
            .Select(p => new PedidoClienteResponse
            {
                Id = p.Id, Numero = p.Numero, Fecha = p.Fecha, Estado = p.Estado, CondicionPago = p.CondicionPago,
            })
            .ToListAsync();

        var devoluciones = await _context.Devoluciones.AsNoTracking()
            .Where(d => d.NotaVenta!.ClienteId == clienteId)
            .OrderByDescending(d => d.Fecha)
            .Take(MaxDocumentos)
            .Select(d => new DevolucionClienteResponse
            {
                Id = d.Id, Numero = d.Numero, NotaVenta = d.NotaVenta!.Numero, Fecha = d.Fecha, Estado = d.Estado, Motivo = d.Motivo,
            })
            .ToListAsync();

        return new DocumentosClienteResponse { Pedidos = pedidos, Devoluciones = devoluciones };
    }

    // ------------------------------------------------------------- Recordatorios

    public async Task<ResumenSeguimientoResponse> ResumenDeAsync(int usuarioId)
    {
        var alcance = await _permisos.AlcanceFiltroAsync(usuarioId, CrmConsultas.Submodulo);
        var misRutas = alcance.RutaIds;

        var programados = _context.GestionesCliente.AsNoTracking()
            .Where(g => g.SeguimientoEstado == EstadoSeguimiento.Programado && g.ProximoSeguimiento != null);

        // El alcance de quien está acotado: los clientes que tiene asignados o que están en sus rutas.
        if (!alcance.SinRestriccion)
        {
            programados = programados.Where(g => g.Cliente!.VendedorId == usuarioId
                                                 || (g.Cliente.RutaId != null && misRutas.Contains(g.Cliente.RutaId.Value)));
        }

        // Los "míos": los que registré yo o son de un cliente mío (asignado o de mis rutas).
        var mios = await programados
            .Where(g => g.UsuarioId == usuarioId
                        || g.Cliente!.VendedorId == usuarioId
                        || (g.Cliente.RutaId != null && misRutas.Contains(g.Cliente.RutaId.Value)))
            .Select(g => g.ProximoSeguimiento!.Value)
            .ToListAsync();

        var ahora = DateTime.UtcNow;
        var hoy = Zona.Hoy;
        var vencidos = mios.Where(m => m < ahora).ToList();

        return new ResumenSeguimientoResponse
        {
            Vencidos = vencidos.Count,
            Hoy = mios.Count(m => m >= ahora && Zona.DiaDe(m) == hoy),
            VencidoDesde = vencidos.Count > 0 ? vencidos.Min() : null,
        };
    }

    // ------------------------------------------------------------- Ayudas

    /// <summary>El cliente existe y quien pregunta puede verlo (el alcance del CRM).</summary>
    private async Task ExigirVisibleAsync(int clienteId)
    {
        if (!await _context.Clientes.AnyAsync(c => c.Id == clienteId))
            throw new NotFoundException("Cliente no encontrado");

        var (visibles, _) = await CrmConsultas.VisiblesAsync(_context, _permisos, _usuarioActual.Id);
        if (!await visibles.AnyAsync(c => c.Id == clienteId))
            throw new ForbiddenException("Este cliente no es de tus rutas");
    }
}
