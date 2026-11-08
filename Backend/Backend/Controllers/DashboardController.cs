using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Los dashboards. Uno por área (ventas, rentabilidad, cobranza, compras,
/// inventario, reparto), cada uno con su propio permiso: se conceden por separado en Accesos.
/// El alcance de datos de quien pregunta (solo lo suyo, por ejemplo) se sigue
/// aplicando dentro de cada bloque.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DashboardController : ControllerBase
{
    private readonly IDashboardService _dashboard;
    private readonly IReportesService _reportes;
    private readonly ICrmProductosService _productos;
    private readonly ICaidaService _caida;
    private readonly IProductosCaidaService _productosCaida;

    public DashboardController(
        IDashboardService dashboard, IReportesService reportes, ICrmProductosService productos, ICaidaService caida,
        IProductosCaidaService productosCaida)
    {
        _dashboard = dashboard;
        _reportes = reportes;
        _productos = productos;
        _caida = caida;
        _productosCaida = productosCaida;
    }

    /// <summary>
    /// Productos con caída: lo que vendió cada producto en el tramo frente al mes anterior (o al año anterior), su estado,
    /// las categorías que más cayeron y la evolución de la venta.
    /// </summary>
    [HttpGet("sin-ventas/analisis")]
    [Permiso("dashboard.sinventas", Accion.Ver)]
    public async Task<IActionResult> AnalisisProductos(
        [FromQuery] DateTime? desde,
        [FromQuery] DateTime? hasta,
        [FromQuery] string? comparar = null,
        [FromQuery] string? medida = null,
        [FromQuery] string? criterio = null,
        [FromQuery] int? almacenId = null,
        [FromQuery] int? categoriaId = null,
        [FromQuery] int? marcaId = null,
        [FromQuery] bool incluirSinStock = false) =>
        Ok(await _productosCaida.AnalisisAsync(desde, hasta, comparar, medida, criterio, almacenId, categoriaId, marcaId, incluirSinStock));

    /// <summary>
    /// Productos activos sin ventas en los últimos días, con su stock y lo que inmovilizan. Con mercado o ruta, los
    /// que no se vendieron a los clientes de ESA zona aunque sí en otras.
    /// </summary>
    [HttpGet("sin-ventas")]
    [Permiso("dashboard.sinventas", Accion.Ver)]
    public async Task<IActionResult> ProductosSinVentas(
        [FromQuery] int dias = 30,
        [FromQuery] int? mercadoId = null,
        [FromQuery] int? rutaId = null,
        [FromQuery] int? categoriaId = null,
        [FromQuery] string? stock = null) =>
        Ok(await _productos.SinVentasAsync(dias, mercadoId, rutaId, categoriaId, stock));

    /// <summary>Cómo le va a cada mercado o ruta (agrupar) frente al mismo tramo del mes (o año) anterior.</summary>
    [HttpGet("zonas")]
    [Permiso("dashboard.zonas", Accion.Ver)]
    public async Task<IActionResult> Zonas(
        [FromQuery] DateTime? desde, [FromQuery] DateTime? hasta, [FromQuery] string? agrupar, [FromQuery] string? comparar) =>
        Ok(await _caida.ZonasAsync(desde, hasta, agrupar, comparar));

    // --- La pestaña Reportes de cada dashboard, con el permiso de ver de ese dashboard ---

    [HttpGet("ventas/reporte")]
    [Permiso("dashboard.ventas", Accion.Ver)]
    public Task<IActionResult> ReporteVentas() => Reporte("ventas");

    [HttpGet("rentabilidad/reporte")]
    [Permiso("dashboard.rentabilidad", Accion.Ver)]
    public Task<IActionResult> ReporteRentabilidad() => Reporte("rentabilidad");

    [HttpGet("cobranza/reporte")]
    [Permiso("dashboard.cobranza", Accion.Ver)]
    public Task<IActionResult> ReporteCobranza() => Reporte("cobranza");

    [HttpGet("compras/reporte")]
    [Permiso("dashboard.compras", Accion.Ver)]
    public Task<IActionResult> ReporteCompras() => Reporte("compras");

    [HttpGet("inventario/reporte")]
    [Permiso("dashboard.inventario", Accion.Ver)]
    public Task<IActionResult> ReporteInventario() => Reporte("inventario");

    [HttpGet("reparto/reporte")]
    [Permiso("dashboard.reparto", Accion.Ver)]
    public Task<IActionResult> ReporteReparto() => Reporte("reparto");

    private async Task<IActionResult> Reporte(string tablero) =>
        Ok(await _reportes.GenerarAsync(tablero, ReporteRequest.DesdeQuery(Request.Query)));

    [HttpGet("ventas")]
    [Permiso("dashboard.ventas", Accion.Ver)]
    public async Task<IActionResult> Ventas([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _dashboard.VentasAsync(desde, hasta));

    [HttpGet("ganancias")]
    [Permiso("dashboard.rentabilidad", Accion.Ver)]
    public async Task<IActionResult> Ganancias([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _dashboard.GananciasAsync(desde, hasta));

    [HttpGet("cobranza")]
    [Permiso("dashboard.cobranza", Accion.Ver)]
    public async Task<IActionResult> Cobranza([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _dashboard.CobranzaAsync(desde, hasta));

    [HttpGet("compras")]
    [Permiso("dashboard.compras", Accion.Ver)]
    public async Task<IActionResult> Compras([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _dashboard.ComprasAsync(desde, hasta));

    [HttpGet("inventario")]
    [Permiso("dashboard.inventario", Accion.Ver)]
    public async Task<IActionResult> Inventario() => Ok(await _dashboard.InventarioAsync());

    [HttpGet("reparto")]
    [Permiso("dashboard.reparto", Accion.Ver)]
    public async Task<IActionResult> Reparto([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _dashboard.RepartoAsync(desde, hasta));
}
