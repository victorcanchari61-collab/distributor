using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>Cómo está un cliente frente a lo que compraba antes.</summary>
public static class NivelCliente
{
    /// <summary>Compra 71 % menos o peor (o dejó de comprar del todo).</summary>
    public const string Critico = "CRITICO";

    public const string Alto = "ALTO";
    public const string Medio = "MEDIO";

    /// <summary>Compra lo mismo, más, o menos de lo que se considera una baja.</summary>
    public const string Estable = "ESTABLE";

    /// <summary>Antes no compraba y ahora sí: no hay con qué compararlo.</summary>
    public const string Nuevo = "NUEVO";

    /// <summary>No compró en ninguno de los dos periodos y lleva días sin comprar.</summary>
    public const string Inactivo = "INACTIVO";

    public static readonly string[] Todos = [Critico, Alto, Medio, Estable, Nuevo, Inactivo];
}

/// <summary>
/// Qué clientes están dejando de comprar.
///
/// Compara lo vendido en el periodo en curso contra el anterior, del mismo largo:
///   - semana: los últimos 7 días contra los 7 anteriores. No es la semana calendario porque el lunes
///     compararía un solo día contra un solo día.
///   - mes: del 1 a hoy contra el mes anterior hasta el mismo día.
///   - año: del 1 de enero a hoy contra el año anterior hasta la misma fecha.
/// Comparar el mismo largo es lo que evita que un mes recién empezado se vea como una caída.
///
/// "Venta" es lo mismo que cuenta el reporte de Ventas: el importe de las líneas de las notas vigentes
/// (con IGV), menos los recojos. Una devolución aprobada ya bajó la línea, así que no se resta otra vez.
/// </summary>
public class CrmService : ICrmService
{
    /// <summary>Sin comprar más de estos días, un cliente se considera inactivo.</summary>
    private const int DiasInactivo = 60;

    private const int MaxCompras = 30;
    private const int MaxProductos = 30;
    private const int MaxDocumentos = 20;

    private static readonly string[] Periodos = ["semana", "mes", "anio"];

    private readonly AppDbContext _context;
    private readonly IPermisoService _permisos;
    private readonly IUsuarioActual _usuarioActual;
    private readonly IValidator<CrearGestionRequest> _gestionValidator;
    private readonly INotificador _notificador;

    public CrmService(
        AppDbContext context,
        IPermisoService permisos,
        IUsuarioActual usuarioActual,
        IValidator<CrearGestionRequest> gestionValidator,
        INotificador notificador)
    {
        _context = context;
        _permisos = permisos;
        _usuarioActual = usuarioActual;
        _gestionValidator = gestionValidator;
        _notificador = notificador;
    }

    // ------------------------------------------------------------- Cartera

    public async Task<CrmCarteraResponse> CarteraAsync(
        string? periodo, int? mercadoId, int? rutaId, int? vendedorId, string? nivel, string? buscar)
    {
        var ventanas = Ventanas(Periodo(periodo), Zona.Hoy);

        if (!string.IsNullOrWhiteSpace(nivel) && !NivelCliente.Todos.Contains(nivel.Trim().ToUpperInvariant()))
            throw new BadRequestException("Ese nivel no existe.");

        var (visibles, soloPropios) = await ClientesVisiblesAsync();
        var clientes = visibles;
        if (mercadoId is int m) clientes = clientes.Where(c => c.MercadoId == m);
        if (rutaId is int r) clientes = clientes.Where(c => c.RutaId == r);
        if (vendedorId is int v) clientes = clientes.Where(c => c.VendedorId == v);
        if (!string.IsNullOrWhiteSpace(buscar))
        {
            var texto = buscar.Trim();
            clientes = clientes.Where(c => c.Nombre.Contains(texto) || c.Documento.Contains(texto));
        }

        var filas = await clientes.Select(Fila).ToListAsync();
        var ventas = await VentasPorClienteAsync(ventanas, null);
        var ultimas = await UltimasComprasAsync();
        var saldos = await SaldosPorCobrarAsync();
        var seguimiento = await SeguimientoPorClienteAsync();
        var categorias = await CategorizacionConsultas.PorClienteAsync(_context);
        var hoy = Zona.Hoy;

        var items = new List<CrmClienteResponse>();
        foreach (var fila in filas)
        {
            ventas.TryGetValue(fila.Id, out var venta);
            ultimas.TryGetValue(fila.Id, out var ultima);
            saldos.TryGetValue(fila.Id, out var saldo);
            seguimiento.TryGetValue(fila.Id, out var seg);

            var item = Armar(fila, venta.Actual, venta.Anterior, ultima == default ? null : ultima, saldo, hoy, seg);
            PonerCategoria(item, categorias);

            // Un cliente que nunca compró, o que compró hace poco pero no en estas ventanas, no es
            // noticia: la lista se queda con los que tienen algo que mirar.
            if (item.Nivel == NivelCliente.Estable && item.Actual == 0 && item.Anterior == 0) continue;
            items.Add(item);
        }

        // El resumen es de todo lo filtrado ANTES de elegir un nivel: si no, al marcar "Crítico" los
        // demás contadores se irían a cero y no habría cómo volver a verlos.
        var resumen = Resumir(items);

        if (!string.IsNullOrWhiteSpace(nivel))
        {
            var elegido = nivel.Trim().ToUpperInvariant();
            items = items.Where(i => i.Nivel == elegido).ToList();
        }

        return new CrmCarteraResponse
        {
            Ventanas = ventanas,
            Resumen = resumen,
            Items = items.OrderBy(i => i.Diferencia).ThenBy(i => i.Nombre).ToList(),
            SoloPropios = soloPropios,
            DiasInactivo = DiasInactivo,
        };
    }

    // ------------------------------------------------------------- Zonas

    public async Task<CrmZonasResponse> ZonasAsync(string? periodo, string? agrupar)
    {
        var por = string.IsNullOrWhiteSpace(agrupar) ? "mercado" : agrupar.Trim().ToLowerInvariant();
        if (por is not ("mercado" or "ruta"))
            throw new BadRequestException("Agrupa por mercado o por ruta.");
        var porMercado = por == "mercado";

        // La misma cartera de siempre, sin filtros: aquí solo se junta por zona.
        var cartera = await CarteraAsync(periodo, null, null, null, null, null);

        var (visibles, soloPropios) = await ClientesVisiblesAsync();
        var activos = await visibles.Where(c => c.Activo)
            .GroupBy(c => porMercado ? c.MercadoId : c.RutaId)
            .Select(g => new { ZonaId = g.Key, Clientes = g.Count() })
            .ToListAsync();

        var nombres = porMercado
            ? await _context.Mercados.AsNoTracking().ToDictionaryAsync(m => m.Id, m => m.Nombre)
            : await _context.Rutas.AsNoTracking().ToDictionaryAsync(r => r.Id, r => r.Nombre);

        var delCliente = cartera.Items.ToLookup(i => porMercado ? i.MercadoId : i.RutaId);
        var totales = activos.ToDictionary(a => a.ZonaId ?? 0, a => a.Clientes);

        // Todas las zonas que tienen clientes o ventas, aunque estén sin actividad.
        var zonas = activos.Select(a => a.ZonaId)
            .Concat(delCliente.Select(g => g.Key))
            .Distinct()
            .ToList();

        var items = zonas.Select(zona =>
        {
            var clientes = delCliente[zona].ToList();
            var actual = clientes.Sum(c => c.Actual);
            var anterior = clientes.Sum(c => c.Anterior);

            return new CrmZonaResponse
            {
                ZonaId = zona,
                Nombre = zona is int id && nombres.TryGetValue(id, out var nombre)
                    ? nombre
                    : porMercado ? "Sin mercado" : "Sin ruta",
                Clientes = totales.GetValueOrDefault(zona ?? 0),
                ConVentas = clientes.Count(c => c.Actual > 0 || c.Anterior > 0),
                Criticos = clientes.Count(c => c.Nivel == NivelCliente.Critico),
                Altos = clientes.Count(c => c.Nivel == NivelCliente.Alto),
                Inactivos = clientes.Count(c => c.Nivel == NivelCliente.Inactivo),
                Nuevos = clientes.Count(c => c.Nivel == NivelCliente.Nuevo),
                Actual = actual,
                Anterior = anterior,
                Diferencia = actual - anterior,
                Variacion = Variacion(actual, anterior),
                VentaPerdida = -clientes.Where(c => c.Diferencia < 0).Sum(c => c.Diferencia),
                SaldoPorCobrar = clientes.Sum(c => c.SaldoPorCobrar),
            };
        })
        .OrderBy(z => z.Diferencia)
        .ThenBy(z => z.Nombre)
        .ToList();

        return new CrmZonasResponse
        {
            Ventanas = cartera.Ventanas,
            Agrupar = por,
            SoloPropios = soloPropios,
            Items = items,
        };
    }

    // ------------------------------------------------------------- Ficha

    public async Task<CrmFichaResponse> FichaAsync(int clienteId, string? periodo)
    {
        var elegido = Periodo(periodo);
        var hoy = Zona.Hoy;

        await ExigirClienteVisibleAsync(clienteId);

        var (visibles, _) = await ClientesVisiblesAsync();
        var fila = await visibles.Where(c => c.Id == clienteId).Select(Fila).FirstAsync();
        var extra = await _context.Clientes.AsNoTracking()
            .Where(c => c.Id == clienteId)
            .Select(c => new
            {
                c.Email,
                c.DiaVisita,
                ListaPrecio = c.ListaPrecio != null ? c.ListaPrecio.Nombre : null,
                c.FechaCreacion,
            })
            .FirstAsync();

        var ultima = (await UltimasComprasAsync(clienteId)).GetValueOrDefault(clienteId);
        var saldo = (await SaldosPorCobrarAsync(clienteId)).GetValueOrDefault(clienteId);
        var seg = (await SeguimientoPorClienteAsync(clienteId)).GetValueOrDefault(clienteId);
        var categorias = await CategorizacionConsultas.PorClienteAsync(_context);

        // Las tres escalas a la vez: quien mira un cliente quiere saber si es de hoy o de hace meses.
        var comparativos = new List<CrmComparativoResponse>();
        CrmClienteResponse? cliente = null;
        foreach (var p in Periodos)
        {
            var ventanas = Ventanas(p, hoy);
            var ventas = (await VentasPorClienteAsync(ventanas, clienteId)).GetValueOrDefault(clienteId);
            var armado = Armar(fila, ventas.Actual, ventas.Anterior, ultima == default ? null : ultima, saldo, hoy, seg);

            comparativos.Add(new CrmComparativoResponse
            {
                Periodo = p,
                Actual = ventanas.Actual,
                Anterior = ventanas.Anterior,
                ImporteActual = armado.Actual,
                ImporteAnterior = armado.Anterior,
                Diferencia = armado.Diferencia,
                Variacion = armado.Variacion,
                Nivel = armado.Nivel,
            });

            if (p == elegido)
            {
                PonerCategoria(armado, categorias);
                cliente = armado;
            }
        }

        return new CrmFichaResponse
        {
            Cliente = cliente!,
            Periodo = elegido,
            Email = extra.Email,
            DiaVisita = extra.DiaVisita,
            ListaPrecio = extra.ListaPrecio,
            FechaAlta = Zona.DiaDe(extra.FechaCreacion),
            Comparativos = comparativos,
            Compras = await ComprasAsync(clienteId),
            ProductosPerdidos = await ProductosPerdidosAsync(clienteId, Ventanas(elegido, hoy)),
            Pedidos = await PedidosAsync(clienteId),
            Devoluciones = await DevolucionesAsync(clienteId),
        };
    }

    // ------------------------------------------------------------- Consultas

    /// <summary>Los datos del maestro de clientes que la cartera muestra, tal como los ve la base.</summary>
    private sealed record FilaCliente(
        int Id, string Documento, string TipoDoc, string Nombre, string? Telefono, string? Direccion,
        string? Distrito, bool Activo, int? RutaId, string? Ruta, int? MercadoId, string? Mercado,
        int? VendedorId, string? Vendedor);

    private static readonly System.Linq.Expressions.Expression<Func<Cliente, FilaCliente>> Fila = c =>
        new FilaCliente(
            c.Id, c.Documento, c.TipoDoc, c.Nombre, c.Telefono, c.Direccion,
            c.Distrito != null ? c.Distrito.Nombre : null,
            c.Activo,
            c.RutaId, c.Ruta != null ? c.Ruta.Nombre : null,
            c.MercadoId, c.Mercado != null ? c.Mercado.Nombre : null,
            c.VendedorId, c.Vendedor != null ? c.Vendedor.Nombre : null);

    /// <summary>
    /// Los clientes que quien pregunta puede ver. Sin restricción, todos; con ella, los de sus rutas
    /// y los que tiene asignados como vendedor.
    /// </summary>
    private async Task<(IQueryable<Cliente> Clientes, bool SoloPropios)> ClientesVisiblesAsync()
    {
        var clientes = _context.Clientes.AsNoTracking();

        if (_usuarioActual.Id is not int uid) return (clientes, false);

        var alcance = await _permisos.AlcanceFiltroAsync(uid, "crm.cartera");
        if (alcance.SinRestriccion) return (clientes, false);

        var rutas = alcance.RutaIds;
        var propio = alcance.UsuarioId;
        return (clientes.Where(c => c.VendedorId == propio
                                    || (c.RutaId != null && rutas.Contains(c.RutaId.Value))), true);
    }

    /// <summary>
    /// Lo vendido a cada cliente en las dos ventanas. Un solo recorrido por las líneas, con la suma hecha
    /// en la base: viaja una fila por cliente.
    /// </summary>
    private async Task<Dictionary<int, (decimal Actual, decimal Anterior)>> VentasPorClienteAsync(
        CrmVentanas ventanas, int? clienteId)
    {
        var actualIni = Zona.AUtc(ventanas.Actual.Desde);
        var actualFin = Zona.AUtc(ventanas.Actual.Hasta.AddDays(1));
        var anteriorIni = Zona.AUtc(ventanas.Anterior.Desde);
        var anteriorFin = Zona.AUtc(ventanas.Anterior.Hasta.AddDays(1));

        var lineas = _context.NotaVentaDetalles
            .Where(d => !d.Anulado
                        && d.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && ((d.NotaVenta.Fecha >= actualIni && d.NotaVenta.Fecha < actualFin)
                            || (d.NotaVenta.Fecha >= anteriorIni && d.NotaVenta.Fecha < anteriorFin)));
        if (clienteId is int id) lineas = lineas.Where(d => d.NotaVenta!.ClienteId == id);

        // La ventana anterior termina antes de que empiece la actual, así que "desde el inicio de la
        // actual" basta para separar una de otra.
        var vendido = await lineas
            .GroupBy(d => d.NotaVenta!.ClienteId)
            .Select(g => new
            {
                ClienteId = g.Key,
                Actual = g.Sum(d => d.NotaVenta!.Fecha >= actualIni ? d.CantidadPresentacion * d.PrecioPresentacion : 0m),
                Anterior = g.Sum(d => d.NotaVenta!.Fecha < actualIni ? d.CantidadPresentacion * d.PrecioPresentacion : 0m),
            })
            .ToListAsync();

        // Lo recogido se resta: es mercadería que el cliente ya no se quedó.
        var recojos = _context.RecojosVenta
            .Where(r => r.Estado != EstadoRecojo.Anulado
                        && r.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && ((r.NotaVenta.Fecha >= actualIni && r.NotaVenta.Fecha < actualFin)
                            || (r.NotaVenta.Fecha >= anteriorIni && r.NotaVenta.Fecha < anteriorFin)));
        if (clienteId is int idr) recojos = recojos.Where(r => r.NotaVenta!.ClienteId == idr);

        var recogido = await recojos
            .GroupBy(r => r.NotaVenta!.ClienteId)
            .Select(g => new
            {
                ClienteId = g.Key,
                Actual = g.Sum(r => r.NotaVenta!.Fecha >= actualIni ? r.Importe : 0m),
                Anterior = g.Sum(r => r.NotaVenta!.Fecha < actualIni ? r.Importe : 0m),
            })
            .ToListAsync();

        var resultado = vendido.ToDictionary(x => x.ClienteId, x => (x.Actual, x.Anterior));
        foreach (var r in recogido)
        {
            resultado.TryGetValue(r.ClienteId, out var base_);
            resultado[r.ClienteId] = (base_.Actual - r.Actual, base_.Anterior - r.Anterior);
        }

        return resultado;
    }

    /// <summary>El día (UTC) de la última venta vigente de cada cliente.</summary>
    private async Task<Dictionary<int, DateTime>> UltimasComprasAsync(int? clienteId = null)
    {
        var notas = _context.NotasVenta.Where(n => n.Estado != EstadoNotaVenta.Anulada);
        if (clienteId is int id) notas = notas.Where(n => n.ClienteId == id);

        return await notas
            .GroupBy(n => n.ClienteId)
            .Select(g => new { ClienteId = g.Key, Ultima = g.Max(n => n.Fecha) })
            .ToDictionaryAsync(x => x.ClienteId, x => x.Ultima);
    }

    /// <summary>
    /// Lo que debe cada cliente hoy. Misma regla de Cuentas por cobrar: ventas a crédito confirmadas
    /// cuyo total supera lo pagado.
    /// </summary>
    private async Task<Dictionary<int, decimal>> SaldosPorCobrarAsync(int? clienteId = null)
    {
        var notas = _context.NotasVenta
            .Where(n => n.Estado == EstadoNotaVenta.Confirmada && n.FormaPago == FormaPagoVenta.Credito);
        if (clienteId is int id) notas = notas.Where(n => n.ClienteId == id);

        var abiertas = await notas
            .Select(n => new
            {
                n.ClienteId,
                Total = n.Detalle.Where(d => !d.Anulado).Sum(d => (decimal?)(d.Cantidad * d.PrecioUnitario)) ?? 0m,
                Pagado = n.Pagos.Where(p => !p.Anulado).Sum(p => (decimal?)p.Monto) ?? 0m,
            })
            .Where(n => n.Total > n.Pagado)
            .AsNoTracking()
            .ToListAsync();

        return abiertas
            .GroupBy(n => n.ClienteId)
            .ToDictionary(g => g.Key, g => Math.Round(g.Sum(n => n.Total - n.Pagado), 2));
    }

    private async Task<List<CrmCompraResponse>> ComprasAsync(int clienteId)
    {
        var notas = await _context.NotasVenta.AsNoTracking()
            .Where(n => n.ClienteId == clienteId)
            .OrderByDescending(n => n.Fecha)
            .Take(MaxCompras)
            .Select(n => new
            {
                n.Id,
                n.Numero,
                n.Fecha,
                n.Estado,
                n.FormaPago,
                Vendedor = n.Usuario != null ? n.Usuario.Nombre : null,
                Total = n.Detalle.Where(d => !d.Anulado).Sum(d => (decimal?)(d.CantidadPresentacion * d.PrecioPresentacion)) ?? 0m,
                Pagado = n.Pagos.Where(p => !p.Anulado).Sum(p => (decimal?)p.Monto) ?? 0m,
            })
            .ToListAsync();

        return notas.Select(n => new CrmCompraResponse
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
        }).ToList();
    }

    /// <summary>
    /// Qué compraba y compra menos: por producto, lo del periodo anterior contra lo del actual.
    /// Cuenta las líneas vendidas, sin descontar recojos (que se registran por producto aparte y no
    /// cambian qué se está dejando de comprar).
    /// </summary>
    private async Task<List<CrmProductoPerdidoResponse>> ProductosPerdidosAsync(int clienteId, CrmVentanas ventanas)
    {
        var actualIni = Zona.AUtc(ventanas.Actual.Desde);
        var actualFin = Zona.AUtc(ventanas.Actual.Hasta.AddDays(1));
        var anteriorIni = Zona.AUtc(ventanas.Anterior.Desde);
        var anteriorFin = Zona.AUtc(ventanas.Anterior.Hasta.AddDays(1));

        var filas = await _context.NotaVentaDetalles
            .Where(d => !d.Anulado
                        && d.NotaVenta!.ClienteId == clienteId
                        && d.NotaVenta.Estado != EstadoNotaVenta.Anulada
                        && ((d.NotaVenta.Fecha >= actualIni && d.NotaVenta.Fecha < actualFin)
                            || (d.NotaVenta.Fecha >= anteriorIni && d.NotaVenta.Fecha < anteriorFin)))
            .GroupBy(d => d.ProductoId)
            .Select(g => new
            {
                ProductoId = g.Key,
                Codigo = g.Max(d => d.Producto!.Codigo),
                Producto = g.Max(d => d.Producto!.Nombre),
                Actual = g.Sum(d => d.NotaVenta!.Fecha >= actualIni ? d.CantidadPresentacion * d.PrecioPresentacion : 0m),
                Anterior = g.Sum(d => d.NotaVenta!.Fecha < actualIni ? d.CantidadPresentacion * d.PrecioPresentacion : 0m),
            })
            .ToListAsync();

        return filas
            .Where(f => f.Anterior > f.Actual)
            .OrderByDescending(f => f.Anterior - f.Actual)
            .Take(MaxProductos)
            .Select(f => new CrmProductoPerdidoResponse
            {
                ProductoId = f.ProductoId,
                Codigo = f.Codigo ?? string.Empty,
                Producto = f.Producto ?? string.Empty,
                Actual = Math.Round(f.Actual, 2),
                Anterior = Math.Round(f.Anterior, 2),
                Diferencia = Math.Round(f.Actual - f.Anterior, 2),
                DejoDeComprar = f.Actual <= 0,
            })
            .ToList();
    }

    private async Task<List<CrmPedidoResponse>> PedidosAsync(int clienteId)
    {
        var pedidos = await _context.Pedidos.AsNoTracking()
            .Where(p => p.ClienteId == clienteId)
            .OrderByDescending(p => p.Fecha)
            .Take(MaxDocumentos)
            .Select(p => new { p.Id, p.Numero, p.Fecha, p.Estado, p.CondicionPago })
            .ToListAsync();

        return pedidos.Select(p => new CrmPedidoResponse
        {
            Id = p.Id,
            Numero = p.Numero,
            Fecha = p.Fecha,
            Estado = p.Estado,
            CondicionPago = p.CondicionPago,
        }).ToList();
    }

    private async Task<List<CrmDevolucionResponse>> DevolucionesAsync(int clienteId)
    {
        var devoluciones = await _context.Devoluciones.AsNoTracking()
            .Where(d => d.NotaVenta!.ClienteId == clienteId)
            .OrderByDescending(d => d.Fecha)
            .Take(MaxDocumentos)
            .Select(d => new { d.Id, d.Numero, NotaVenta = d.NotaVenta!.Numero, d.Fecha, d.Estado, d.Motivo })
            .ToListAsync();

        return devoluciones.Select(d => new CrmDevolucionResponse
        {
            Id = d.Id,
            Numero = d.Numero,
            NotaVenta = d.NotaVenta,
            Fecha = d.Fecha,
            Estado = d.Estado,
            Motivo = d.Motivo,
        }).ToList();
    }

    // ------------------------------------------------------------- Gestiones

    public async Task<List<GestionResponse>> GestionesAsync(int clienteId)
    {
        await ExigirClienteVisibleAsync(clienteId);

        var hoy = Zona.Hoy;
        var gestiones = await _context.GestionesCliente.AsNoTracking()
            .Where(g => g.ClienteId == clienteId)
            .OrderByDescending(g => g.Fecha)
            .Select(Gestion)
            .ToListAsync();

        foreach (var g in gestiones) g.Vencida = EstaVencida(g.Cumplida, g.ProximaFecha, hoy);
        return gestiones;
    }

    public async Task<GestionResponse> RegistrarGestionAsync(int clienteId, CrearGestionRequest request)
    {
        await _gestionValidator.ValidateAndThrowAsync(request);
        await ExigirClienteVisibleAsync(clienteId);

        var proxima = request.ProximaFecha?.Date;
        if (proxima is DateTime dia && dia < Zona.Hoy)
            throw new BadRequestException("El día de la próxima acción no puede ser anterior a hoy");

        var gestion = new GestionCliente
        {
            ClienteId = clienteId,
            Tipo = request.Tipo,
            Resultado = request.Resultado,
            Nota = request.Nota.Trim(),
            ProximaAccion = proxima is null ? null : request.ProximaAccion!.Trim(),
            ProximaFecha = proxima,
            UsuarioId = _usuarioActual.Id,
        };

        _context.GestionesCliente.Add(gestion);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("seguimientos", "creado", new { clienteId, id = gestion.Id });
        return await UnaGestionAsync(gestion.Id);
    }

    public async Task<GestionResponse> CumplirGestionAsync(int gestionId, CumplirGestionRequest request)
    {
        var gestion = await _context.GestionesCliente.FirstOrDefaultAsync(g => g.Id == gestionId)
            ?? throw new NotFoundException("Gestión no encontrada");
        await ExigirClienteVisibleAsync(gestion.ClienteId);

        if (gestion.ProximaFecha is null)
            throw new BadRequestException("Esta gestión no dejó ninguna acción pendiente");

        gestion.Cumplida = request.Cumplida;
        gestion.CumplidaEn = request.Cumplida ? DateTime.UtcNow : null;
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("seguimientos", "actualizado", new { clienteId = gestion.ClienteId, id = gestion.Id });
        return await UnaGestionAsync(gestion.Id);
    }

    public async Task EliminarGestionAsync(int gestionId)
    {
        var gestion = await _context.GestionesCliente.FirstOrDefaultAsync(g => g.Id == gestionId)
            ?? throw new NotFoundException("Gestión no encontrada");
        await ExigirClienteVisibleAsync(gestion.ClienteId);

        _context.GestionesCliente.Remove(gestion);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("seguimientos", "eliminado", new { clienteId = gestion.ClienteId, id = gestionId });
    }

    private static readonly System.Linq.Expressions.Expression<Func<GestionCliente, GestionResponse>> Gestion = g =>
        new GestionResponse
        {
            Id = g.Id,
            ClienteId = g.ClienteId,
            Fecha = g.Fecha,
            Tipo = g.Tipo,
            Resultado = g.Resultado,
            Nota = g.Nota,
            ProximaAccion = g.ProximaAccion,
            ProximaFecha = g.ProximaFecha,
            Cumplida = g.Cumplida,
            CumplidaEn = g.CumplidaEn,
            UsuarioId = g.UsuarioId,
            Usuario = g.Usuario != null ? g.Usuario.Nombre : null,
        };

    private async Task<GestionResponse> UnaGestionAsync(int id)
    {
        var gestion = await _context.GestionesCliente.AsNoTracking()
            .Where(g => g.Id == id)
            .Select(Gestion)
            .FirstAsync();

        gestion.Vencida = EstaVencida(gestion.Cumplida, gestion.ProximaFecha, Zona.Hoy);
        return gestion;
    }

    /// <summary>Una acción sigue abierta y su día ya pasó.</summary>
    private static bool EstaVencida(bool cumplida, DateTime? proximaFecha, DateTime hoy) =>
        !cumplida && proximaFecha is DateTime dia && dia < hoy;

    /// <summary>El cliente existe y quien pregunta puede verlo (mismo alcance que la cartera).</summary>
    private async Task ExigirClienteVisibleAsync(int clienteId)
    {
        if (!await _context.Clientes.AnyAsync(c => c.Id == clienteId))
            throw new NotFoundException("Cliente no encontrado");

        var (visibles, _) = await ClientesVisiblesAsync();
        if (!await visibles.AnyAsync(c => c.Id == clienteId))
            throw new ForbiddenException("Este cliente no es de tus rutas");
    }

    /// <summary>Lo que el seguimiento sabe de un cliente: su próxima acción abierta y su última gestión.</summary>
    private sealed record Seguimiento(string? Accion, DateTime? Fecha, DateTime? Ultima);

    private async Task<Dictionary<int, Seguimiento>> SeguimientoPorClienteAsync(int? clienteId = null)
    {
        var gestiones = _context.GestionesCliente.AsNoTracking();
        if (clienteId is int id) gestiones = gestiones.Where(g => g.ClienteId == id);

        var ultimas = await gestiones
            .GroupBy(g => g.ClienteId)
            .Select(g => new { ClienteId = g.Key, Ultima = g.Max(x => x.Fecha) })
            .ToListAsync();

        // Las acciones abiertas son pocas: se traen y se queda la más próxima de cada cliente.
        var abiertas = (await gestiones
                .Where(g => !g.Cumplida && g.ProximaFecha != null)
                .Select(g => new { g.ClienteId, g.ProximaFecha, g.ProximaAccion })
                .ToListAsync())
            .GroupBy(g => g.ClienteId)
            .ToDictionary(g => g.Key, g => g.OrderBy(x => x.ProximaFecha).First());

        return ultimas.ToDictionary(
            u => u.ClienteId,
            u => abiertas.TryGetValue(u.ClienteId, out var a)
                ? new Seguimiento(a.ProximaAccion, a.ProximaFecha, u.Ultima)
                : new Seguimiento(null, null, u.Ultima));
    }

    // ------------------------------------------------------------- Reglas

    private static string Periodo(string? periodo)
    {
        if (string.IsNullOrWhiteSpace(periodo)) return "mes";

        var p = periodo.Trim().ToLowerInvariant();
        if (!Periodos.Contains(p))
            throw new BadRequestException("El periodo debe ser semana, mes o anio.");
        return p;
    }

    /// <summary>El periodo en curso y el anterior del mismo largo (ver el resumen de la clase).</summary>
    internal static CrmVentanas Ventanas(string periodo, DateTime hoy)
    {
        DateTime actualDesde, anteriorDesde, anteriorHasta;

        switch (periodo)
        {
            case "semana":
                actualDesde = hoy.AddDays(-6);
                anteriorDesde = hoy.AddDays(-13);
                anteriorHasta = hoy.AddDays(-7);
                break;

            case "anio":
                actualDesde = new DateTime(hoy.Year, 1, 1);
                anteriorDesde = new DateTime(hoy.Year - 1, 1, 1);
                // El 29 de febrero no existe en el año anterior: se queda en el último día de ese mes.
                anteriorHasta = new DateTime(hoy.Year - 1, hoy.Month,
                    Math.Min(hoy.Day, DateTime.DaysInMonth(hoy.Year - 1, hoy.Month)));
                break;

            default:
                actualDesde = new DateTime(hoy.Year, hoy.Month, 1);
                anteriorDesde = actualDesde.AddMonths(-1);
                // Un 31 contra un mes de 30 días: hasta el último día de ese mes, no se desborda al siguiente.
                anteriorHasta = anteriorDesde.AddDays(
                    Math.Min(hoy.Day, DateTime.DaysInMonth(anteriorDesde.Year, anteriorDesde.Month)) - 1);
                break;
        }

        return new CrmVentanas
        {
            Periodo = periodo,
            Actual = new CrmRango { Desde = actualDesde, Hasta = hoy },
            Anterior = new CrmRango { Desde = anteriorDesde, Hasta = anteriorHasta },
        };
    }

    /// <summary>Cuánto cambió, en porcentaje. Nulo si antes no había nada con qué comparar.</summary>
    private static decimal? Variacion(decimal actual, decimal anterior) =>
        anterior > 0 ? Math.Round((actual - anterior) / anterior * 100m, 1) : null;

    internal static string Nivel(decimal actual, decimal anterior, bool inactivo)
    {
        if (anterior <= 0)
        {
            if (actual > 0) return NivelCliente.Nuevo;
            return inactivo ? NivelCliente.Inactivo : NivelCliente.Estable;
        }

        var caida = (anterior - actual) / anterior * 100m;
        if (caida >= 71m) return NivelCliente.Critico;
        if (caida >= 40m) return NivelCliente.Alto;
        if (caida >= 15m) return NivelCliente.Medio;
        return NivelCliente.Estable;
    }

    /// <summary>La categoría del último cálculo de Categorización, si el cliente entró en él.</summary>
    private static void PonerCategoria(CrmClienteResponse item, Dictionary<int, CategoriaVigente> categorias)
    {
        if (!categorias.TryGetValue(item.ClienteId, out var categoria)) return;

        item.CategoriaCodigo = categoria.Codigo;
        item.Categoria = categoria.Nombre;
        item.CategoriaColor = categoria.Color;
    }

    private static CrmClienteResponse Armar(
        FilaCliente fila, decimal actual, decimal anterior, DateTime? ultimaCompra, decimal saldo, DateTime hoy,
        Seguimiento? seguimiento)
    {
        actual = Math.Round(actual, 2);
        anterior = Math.Round(anterior, 2);

        var dias = ultimaCompra is DateTime u ? Math.Max(0, (int)(hoy - Zona.DiaDe(u)).TotalDays) : (int?)null;
        var inactivo = dias is int d && d > DiasInactivo;

        return new CrmClienteResponse
        {
            ClienteId = fila.Id,
            Codigo = $"CLI{fila.Id:D5}",
            Documento = fila.Documento,
            TipoDoc = fila.TipoDoc,
            Nombre = fila.Nombre,
            Telefono = fila.Telefono,
            Direccion = fila.Direccion,
            Distrito = fila.Distrito,
            Activo = fila.Activo,
            RutaId = fila.RutaId,
            Ruta = fila.Ruta,
            MercadoId = fila.MercadoId,
            Mercado = fila.Mercado,
            VendedorId = fila.VendedorId,
            Vendedor = fila.Vendedor,
            Actual = actual,
            Anterior = anterior,
            Diferencia = actual - anterior,
            Variacion = Variacion(actual, anterior),
            Nivel = Nivel(actual, anterior, inactivo),
            UltimaCompra = ultimaCompra is DateTime ult ? Zona.DiaDe(ult) : null,
            DiasSinComprar = dias,
            Inactivo = inactivo,
            SaldoPorCobrar = saldo,
            ProximaAccion = seguimiento?.Accion,
            ProximaFecha = seguimiento?.Fecha,
            AccionVencida = seguimiento?.Fecha is DateTime dia && dia < hoy,
            UltimaGestion = seguimiento?.Ultima,
        };
    }

    private static CrmResumenResponse Resumir(List<CrmClienteResponse> items)
    {
        var actual = items.Sum(i => i.Actual);
        var anterior = items.Sum(i => i.Anterior);

        return new CrmResumenResponse
        {
            Clientes = items.Count,
            Criticos = items.Count(i => i.Nivel == NivelCliente.Critico),
            Altos = items.Count(i => i.Nivel == NivelCliente.Alto),
            Medios = items.Count(i => i.Nivel == NivelCliente.Medio),
            Estables = items.Count(i => i.Nivel == NivelCliente.Estable),
            Nuevos = items.Count(i => i.Nivel == NivelCliente.Nuevo),
            Inactivos = items.Count(i => i.Nivel == NivelCliente.Inactivo),
            AccionesVencidas = items.Count(i => i.AccionVencida),
            Actual = actual,
            Anterior = anterior,
            Diferencia = actual - anterior,
            Variacion = Variacion(actual, anterior),
            VentaPerdida = -items.Where(i => i.Diferencia < 0).Sum(i => i.Diferencia),
        };
    }
}
