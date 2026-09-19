using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Los dashboards. Uno por área (ventas, rentabilidad, cobranza, inventario,
/// reparto), cada uno con su propio permiso: se conceden por separado en Accesos.
/// El alcance de datos de quien pregunta (solo lo suyo, por ejemplo) se sigue
/// aplicando dentro de cada bloque.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DashboardController : ControllerBase
{
    private readonly IDashboardService _dashboard;

    public DashboardController(IDashboardService dashboard)
    {
        _dashboard = dashboard;
    }

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

    [HttpGet("inventario")]
    [Permiso("dashboard.inventario", Accion.Ver)]
    public async Task<IActionResult> Inventario() => Ok(await _dashboard.InventarioAsync());

    [HttpGet("reparto")]
    [Permiso("dashboard.reparto", Accion.Ver)]
    public async Task<IActionResult> Reparto([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _dashboard.RepartoAsync(desde, hasta));
}
