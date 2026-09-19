using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// El tablero de inicio. Un endpoint por bloque, cada uno con el permiso de la
/// pantalla de donde salen sus datos: así el tablero nunca deja ver lo que la
/// pantalla de origen no dejaría, y la web pide solo los bloques a los que
/// tiene acceso.
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
    [Permiso("fact.notaventa", Accion.Ver)]
    public async Task<IActionResult> Ventas([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _dashboard.VentasAsync(desde, hasta));

    [HttpGet("ganancias")]
    [Permiso("finanzas.ganancias", Accion.Ver)]
    public async Task<IActionResult> Ganancias([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _dashboard.GananciasAsync(desde, hasta));

    [HttpGet("cobranza")]
    [Permiso("finanzas.cobrar", Accion.Ver)]
    public async Task<IActionResult> Cobranza([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _dashboard.CobranzaAsync(desde, hasta));

    [HttpGet("inventario")]
    [Permiso("inv.stock", Accion.Ver)]
    public async Task<IActionResult> Inventario() => Ok(await _dashboard.InventarioAsync());

    [HttpGet("reparto")]
    [Permiso("fact.pedidos", Accion.Ver)]
    public async Task<IActionResult> Reparto([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _dashboard.RepartoAsync(desde, hasta));
}
