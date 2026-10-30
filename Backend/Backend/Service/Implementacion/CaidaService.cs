using Backend.Data;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Los reportes de CRM sobre la caída de ventas.
///
/// Todos miden lo mismo y con la misma regla: el estado de un cliente por cuánto cayó su compra frente al mismo tramo
/// del año anterior (<see cref="EstadoCaida"/>). Por eso el estado que ve el vendedor en la ficha, el del reporte de
/// Clientes con caída y el de Vendedores con caída siempre coinciden.
///
/// El alcance de quien pregunta manda: quien solo ve "sus clientes" no ve la cartera de otro.
/// </summary>
public class CaidaService : ICaidaService
{
    /// <summary>Sin comprar menos días que estos, el cliente está activo y no es "inactivo".</summary>

    private readonly AppDbContext _context;
    private readonly IPermisoService _permisos;
    private readonly IUsuarioActual _usuarioActual;

    public CaidaService(AppDbContext context, IPermisoService permisos, IUsuarioActual usuarioActual)
    {
        _context = context;
        _permisos = permisos;
        _usuarioActual = usuarioActual;
    }

    // ------------------------------------------------------------- Clientes con caída

    public async Task<CaidaClientesResponse> ClientesAsync(ConsultaCaida consulta)
    {
        ValidarEstado(consulta.Estado, EstadoCaida.Todos);
        var periodo = PeriodoComparado.Crear(consulta.Desde, consulta.Hasta, Zona.Hoy);

        var (filas, soloPropios) = await FilasAsync(periodo, consulta.MercadoId, consulta.RutaId, consulta.VendedorId, consulta.Buscar);

        // Las tarjetas son de todo lo filtrado ANTES de elegir un estado: si no, al tocar "Crítico" las demás
        // se irían a cero y no habría cómo volver a verlas.
        var estados = EstadoCaida.Todos.Select(e => new EstadoResumenResponse
        {
            Estado = e,
            Etiqueta = EstadoCaida.Etiqueta(e),
            Clientes = filas.Count(f => f.Estado == e),
            Monto = filas.Where(f => f.Estado == e).Sum(f => f.MontoRiesgo),
        }).ToList();

        var items = string.IsNullOrWhiteSpace(consulta.Estado)
            ? filas
            : filas.Where(f => f.Estado == consulta.Estado!.Trim().ToUpperInvariant()).ToList();

        return new CaidaClientesResponse
        {
            Periodo = Describir(periodo),
            Estados = estados,
            VentaAnterior = filas.Sum(f => f.VentaAnterior),
            VentaActual = filas.Sum(f => f.VentaActual),
            SoloPropios = soloPropios,
            // Lo más grave primero y, dentro de cada estado, la mayor plata en juego.
            Items = items
                .OrderBy(f => Array.IndexOf(EstadoCaida.Todos, f.Estado))
                .ThenByDescending(f => f.MontoRiesgo)
                .ThenBy(f => f.Cliente)
                .ToList(),
        };
    }

    /// <summary>
    /// Una fila por cliente activo que compró en alguno de los dos tramos, con su estado, su última gestión y lo que
    /// debe. Es la base de este reporte, de Zonas y de lo que Visitas muestra.
    /// </summary>
    private async Task<(List<CaidaFilaResponse> Filas, bool SoloPropios)> FilasAsync(
        PeriodoComparado periodo, int? mercadoId, int? rutaId, int? vendedorId, string? buscar)
    {
        var (visibles, soloPropios) = await CrmConsultas.VisiblesAsync(_context, _permisos, _usuarioActual.Id);

        var clientes = visibles.Where(c => c.Activo);
        if (mercadoId is int m) clientes = clientes.Where(c => c.MercadoId == m);
        if (rutaId is int r) clientes = clientes.Where(c => c.RutaId == r);
        if (vendedorId is int v) clientes = clientes.Where(c => c.VendedorId == v);
        if (!string.IsNullOrWhiteSpace(buscar))
        {
            var texto = buscar.Trim();
            clientes = clientes.Where(c => c.Nombre.Contains(texto) || c.Documento.Contains(texto));
        }

        var datos = await clientes.Select(CrmConsultas.Fila).ToListAsync();
        var ventas = await CrmConsultas.VentasPorClienteAsync(_context, periodo);
        var ultimas = await CrmConsultas.UltimasComprasAsync(_context);
        var saldos = await CrmConsultas.SaldosPorCobrarAsync(_context);
        var gestiones = await CrmConsultas.GestionesPorClienteAsync(_context);
        var categorias = await CategorizacionConsultas.PorClienteAsync(_context);

        var hoy = Zona.Hoy;
        var ahora = DateTime.UtcNow;
        var filas = new List<CaidaFilaResponse>();

        foreach (var c in datos)
        {
            ventas.TryGetValue(c.Id, out var venta);
            if (venta.Actual <= 0 && venta.Anterior <= 0) continue;

            ultimas.TryGetValue(c.Id, out var ultima);
            gestiones.TryGetValue(c.Id, out var gestion);
            categorias.TryGetValue(c.Id, out var categoria);

            var actual = Math.Round(venta.Actual, 2);
            var anterior = Math.Round(venta.Anterior, 2);
            var (etiquetaGestion, tonoGestion) = gestion?.Resultado is string res ? ResultadoGestion.De(res) : (null, null);

            filas.Add(new CaidaFilaResponse
            {
                Id = c.Id,
                Codigo = $"CLI{c.Id:D5}",
                Cliente = c.Nombre,
                Documento = c.Documento,
                Telefono = c.Telefono,
                Vendedor = c.Vendedor,
                VendedorId = c.VendedorId,
                Mercado = c.Mercado,
                MercadoId = c.MercadoId,
                Ruta = c.Ruta,
                RutaId = c.RutaId,
                CategoriaCodigo = categoria?.Codigo,
                Categoria = categoria?.Nombre,
                CategoriaColor = categoria?.Color,
                UltimaCompra = ultima == default ? null : Zona.DiaDe(ultima),
                DiasSinCompra = ultima == default ? null : Math.Max(0, (int)(hoy - Zona.DiaDe(ultima)).TotalDays),
                VentaAnterior = anterior,
                VentaActual = actual,
                Variacion = actual - anterior,
                CaidaPct = EstadoCaida.CaidaPct(actual, anterior),
                MontoRiesgo = anterior > actual ? anterior - actual : 0m,
                Estado = EstadoCaida.Clasificar(actual, anterior),
                SaldoPorCobrar = saldos.GetValueOrDefault(c.Id),
                GestionResultado = gestion?.Resultado,
                GestionEtiqueta = etiquetaGestion,
                GestionTono = tonoGestion,
                GestionFecha = gestion?.Fecha,
                ProximoSeguimiento = gestion?.Proximo,
                ProximaAccion = gestion?.Accion,
                SeguimientoVencido = gestion?.Proximo is DateTime p && p < ahora,
            });
        }

        return (filas, soloPropios);
    }

    // ------------------------------------------------------------- Qué dejó de comprar

    public async Task<QueDejoDeComprarResponse> QueDejoDeComprarAsync(int clienteId, DateTime? desde, DateTime? hasta)
    {
        var periodo = PeriodoComparado.Crear(desde, hasta, Zona.Hoy);

        var (visibles, _) = await CrmConsultas.VisiblesAsync(_context, _permisos, _usuarioActual.Id);
        var cliente = await visibles.Where(c => c.Id == clienteId).Select(c => c.Nombre).FirstOrDefaultAsync();
        if (cliente is null)
        {
            if (!await _context.Clientes.AnyAsync(c => c.Id == clienteId))
                throw new NotFoundException("Cliente no encontrado");
            throw new ForbiddenException("Este cliente no es de tus rutas");
        }

        return new QueDejoDeComprarResponse
        {
            ClienteId = clienteId,
            Cliente = cliente,
            Periodo = Describir(periodo),
            Productos = await ProductosDelClienteAsync(_context, clienteId, periodo),
        };
    }

    /// <summary>
    /// Cada producto que el cliente compró en alguno de los dos tramos, con qué le pasó: lo dejó, es nuevo, igual,
    /// compra más o compra menos. Lo que dejó de comprar va primero.
    /// </summary>
    public static async Task<List<SituacionProductoResponse>> ProductosDelClienteAsync(
        AppDbContext context, int clienteId, PeriodoComparado p)
    {
        var actualIni = p.ActualIni;
        var actualFin = p.ActualFin;
        var anteriorIni = p.AnteriorIni;
        var anteriorFin = p.AnteriorFin;

        var filas = await context.NotaVentaDetalles.AsNoTracking()
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
                Actual = g.Sum(d => d.NotaVenta!.Fecha >= actualIni && d.NotaVenta.Fecha < actualFin
                    ? d.CantidadPresentacion * d.PrecioPresentacion : 0m),
                Anterior = g.Sum(d => d.NotaVenta!.Fecha >= anteriorIni && d.NotaVenta.Fecha < anteriorFin
                    ? d.CantidadPresentacion * d.PrecioPresentacion : 0m),
            })
            .ToListAsync();

        string Situacion(decimal actual, decimal anterior) =>
            anterior > 0 && actual <= 0 ? "DEJO"
            : anterior <= 0 && actual > 0 ? "NUEVO"
            : actual == anterior ? "IGUAL"
            : actual > anterior ? "MAS" : "MENOS";

        string[] orden = ["DEJO", "MENOS", "IGUAL", "MAS", "NUEVO"];

        return filas
            .Select(f => new SituacionProductoResponse
            {
                ProductoId = f.ProductoId,
                Codigo = f.Codigo ?? string.Empty,
                Producto = f.Producto ?? string.Empty,
                VentaAnterior = Math.Round(f.Anterior, 2),
                VentaActual = Math.Round(f.Actual, 2),
                Variacion = Math.Round(f.Actual - f.Anterior, 2),
                Situacion = Situacion(f.Actual, f.Anterior),
            })
            .OrderBy(f => Array.IndexOf(orden, f.Situacion))
            .ThenBy(f => f.Variacion)
            .ThenBy(f => f.Producto)
            .ToList();
    }

    // ------------------------------------------------------------- Vendedores con caída

    public async Task<VendedoresCaidaResponse> VendedoresAsync(DateTime? desde, DateTime? hasta)
    {
        var periodo = PeriodoComparado.Crear(desde, hasta, Zona.Hoy);

        var (visibles, _) = await CrmConsultas.VisiblesAsync(_context, _permisos, _usuarioActual.Id);
        var clienteIds = visibles.Select(c => c.Id);

        var actualIni = periodo.ActualIni;
        var actualFin = periodo.ActualFin;
        var anteriorIni = periodo.AnteriorIni;
        var anteriorFin = periodo.AnteriorFin;

        // Lo que vendió cada vendedor a cada cliente en los dos tramos: de ahí salen sus totales y sus clientes.
        var lineas = await _context.NotaVentaDetalles.AsNoTracking()
            .Where(d => !d.Anulado
                        && d.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && clienteIds.Contains(d.NotaVenta.ClienteId)
                        && ((d.NotaVenta.Fecha >= actualIni && d.NotaVenta.Fecha < actualFin)
                            || (d.NotaVenta.Fecha >= anteriorIni && d.NotaVenta.Fecha < anteriorFin)))
            .GroupBy(d => new { d.NotaVenta!.UsuarioId, d.NotaVenta.ClienteId })
            .Select(g => new
            {
                g.Key.UsuarioId,
                g.Key.ClienteId,
                Actual = g.Sum(d => d.NotaVenta!.Fecha >= actualIni && d.NotaVenta.Fecha < actualFin
                    ? d.CantidadPresentacion * d.PrecioPresentacion : 0m),
                Anterior = g.Sum(d => d.NotaVenta!.Fecha >= anteriorIni && d.NotaVenta.Fecha < anteriorFin
                    ? d.CantidadPresentacion * d.PrecioPresentacion : 0m),
            })
            .ToListAsync();

        var nombres = await _context.Usuarios.AsNoTracking().ToDictionaryAsync(u => u.Id, u => u.Nombre);

        var filas = lineas
            .GroupBy(l => l.UsuarioId ?? 0)
            .Select(g =>
            {
                var actual = Math.Round(g.Sum(l => l.Actual), 2);
                var anterior = Math.Round(g.Sum(l => l.Anterior), 2);
                // El estado de cada cliente de ESE vendedor: cuántos de los suyos están cayendo.
                var estadosClientes = g.Select(l => (Estado: EstadoCaida.Clasificar(l.Actual, l.Anterior), Riesgo: Math.Max(0m, l.Anterior - l.Actual))).ToList();
                string[] enCaida = [EstadoCaida.Critico, EstadoCaida.Riesgo, EstadoCaida.Seguimiento];

                return new VendedorCaidaFilaResponse
                {
                    UsuarioId = g.Key,
                    Vendedor = g.Key == 0 ? "Sin vendedor" : nombres.GetValueOrDefault(g.Key) ?? "Vendedor",
                    VentaAnterior = anterior,
                    VentaActual = actual,
                    Variacion = actual - anterior,
                    CaidaPct = EstadoCaida.CaidaPct(actual, anterior),
                    Estado = EstadoCaida.Clasificar(actual, anterior),
                    Clientes = g.Count(),
                    ClientesEnCaida = estadosClientes.Count(e => enCaida.Contains(e.Estado)),
                    ClientesCriticos = estadosClientes.Count(e => e.Estado == EstadoCaida.Critico),
                    MontoRiesgo = Math.Round(estadosClientes.Where(e => enCaida.Contains(e.Estado)).Sum(e => e.Riesgo), 2),
                };
            })
            .Where(f => f.VentaActual > 0 || f.VentaAnterior > 0)
            .ToList();

        return new VendedoresCaidaResponse
        {
            Periodo = Describir(periodo),
            Estados = EstadoCaida.Todos.Select(e => new EstadoResumenResponse
            {
                Estado = e,
                Etiqueta = EstadoCaida.Etiqueta(e),
                Clientes = filas.Count(f => f.Estado == e),
                Monto = filas.Where(f => f.Estado == e).Sum(f => Math.Max(0m, f.VentaAnterior - f.VentaActual)),
            }).ToList(),
            Items = filas
                .OrderBy(f => Array.IndexOf(EstadoCaida.Todos, f.Estado))
                .ThenBy(f => f.Variacion)
                .ToList(),
        };
    }

    // ------------------------------------------------------------- Zonas (dashboard)

    public async Task<ZonasCaidaResponse> ZonasAsync(DateTime? desde, DateTime? hasta, string? agrupar)
    {
        var por = string.IsNullOrWhiteSpace(agrupar) ? "mercado" : agrupar.Trim().ToLowerInvariant();
        if (por is not ("mercado" or "ruta"))
            throw new BadRequestException("Agrupa por mercado o por ruta.");
        var porMercado = por == "mercado";

        var periodo = PeriodoComparado.Crear(desde, hasta, Zona.Hoy);
        var (filas, soloPropios) = await FilasAsync(periodo, null, null, null, null);

        var (visibles, _) = await CrmConsultas.VisiblesAsync(_context, _permisos, _usuarioActual.Id);
        var activos = await visibles.Where(c => c.Activo)
            .GroupBy(c => porMercado ? c.MercadoId : c.RutaId)
            .Select(g => new { ZonaId = g.Key, Clientes = g.Count() })
            .ToListAsync();

        var nombres = porMercado
            ? await _context.Mercados.AsNoTracking().ToDictionaryAsync(m => m.Id, m => m.Nombre)
            : await _context.Rutas.AsNoTracking().ToDictionaryAsync(r => r.Id, r => r.Nombre);

        var delCliente = filas.ToLookup(f => porMercado ? f.MercadoId : f.RutaId);
        var totales = activos.ToDictionary(a => a.ZonaId ?? 0, a => a.Clientes);

        // Todas las zonas que tienen clientes o ventas, aunque estén sin actividad.
        var zonas = activos.Select(a => a.ZonaId).Concat(delCliente.Select(g => g.Key)).Distinct().ToList();

        var items = zonas.Select(zona =>
        {
            var clientes = delCliente[zona].ToList();
            var actual = clientes.Sum(c => c.VentaActual);
            var anterior = clientes.Sum(c => c.VentaAnterior);

            return new ZonaCaidaResponse
            {
                ZonaId = zona,
                Nombre = zona is int id && nombres.TryGetValue(id, out var nombre)
                    ? nombre
                    : porMercado ? "Sin mercado" : "Sin ruta",
                Clientes = totales.GetValueOrDefault(zona ?? 0),
                ConVentas = clientes.Count,
                Criticos = clientes.Count(c => c.Estado == EstadoCaida.Critico),
                EnRiesgo = clientes.Count(c => c.Estado == EstadoCaida.Riesgo),
                EnSeguimiento = clientes.Count(c => c.Estado == EstadoCaida.Seguimiento),
                SinComparacion = clientes.Count(c => c.Estado == EstadoCaida.SinBase),
                VentaAnterior = anterior,
                VentaActual = actual,
                Variacion = actual - anterior,
                CaidaPct = EstadoCaida.CaidaPct(actual, anterior),
                VentaPerdida = clientes.Sum(c => c.MontoRiesgo),
                SaldoPorCobrar = clientes.Sum(c => c.SaldoPorCobrar),
            };
        })
        .OrderByDescending(z => z.VentaPerdida)
        .ThenBy(z => z.Variacion)
        .ThenBy(z => z.Nombre)
        .ToList();

        return new ZonasCaidaResponse
        {
            Periodo = Describir(periodo),
            Agrupar = por,
            SoloPropios = soloPropios,
            Items = items,
        };
    }

    // ------------------------------------------------------------- Ayudas

    private static void ValidarEstado(string? estado, string[] validos)
    {
        if (string.IsNullOrWhiteSpace(estado)) return;
        if (!validos.Contains(estado.Trim().ToUpperInvariant()))
            throw new BadRequestException("Ese estado no existe en este reporte.");
    }

    public static PeriodoCaidaResponse Describir(PeriodoComparado p) => new()
    {
        Actual = new RangoResponse { Desde = p.Desde, Hasta = p.Hasta },
        Anterior = new RangoResponse { Desde = p.AnteriorDesde, Hasta = p.AnteriorHasta },
        Etiqueta = CrmConsultas.Etiqueta(p.Desde, p.Hasta),
        EtiquetaAnterior = CrmConsultas.Etiqueta(p.AnteriorDesde, p.AnteriorHasta),
    };
}
