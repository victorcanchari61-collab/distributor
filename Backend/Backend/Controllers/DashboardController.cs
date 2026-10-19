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

    public DashboardController(IDashboardService dashboard, IReportesService reportes)
    {
        _dashboard = dashboard;
        _reportes = reportes;
    }

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
