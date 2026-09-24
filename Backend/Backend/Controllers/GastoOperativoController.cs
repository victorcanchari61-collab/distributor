using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/gastooperativo")]
[Authorize]
public class GastoOperativoController : ControllerBase
{
    private readonly IGastoOperativoService _gastos;

    public GastoOperativoController(IGastoOperativoService gastos)
    {
        _gastos = gastos;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    // --- Plantillas recurrentes ---

    [HttpGet("recurrentes")]
    [Permiso("finanzas.operativos", Accion.Ver)]
    public async Task<IActionResult> GetRecurrentes() => Ok(await _gastos.GetRecurrentesAsync());

    [HttpPost("recurrentes")]
    [Permiso("finanzas.operativos", Accion.Crear)]
    public async Task<IActionResult> CrearRecurrente([FromBody] GastoRecurrenteRequest request) =>
        Ok(await _gastos.CrearRecurrenteAsync(request));

    [HttpPut("recurrentes/{id:int}")]
    [Permiso("finanzas.operativos", Accion.Editar)]
    public async Task<IActionResult> ActualizarRecurrente(int id, [FromBody] GastoRecurrenteRequest request) =>
        Ok(await _gastos.ActualizarRecurrenteAsync(id, request));

    [HttpDelete("recurrentes/{id:int}")]
    [Permiso("finanzas.operativos", Accion.Eliminar)]
    public async Task<IActionResult> EliminarRecurrente(int id)
    {
        await _gastos.EliminarRecurrenteAsync(id);
        return NoContent();
    }

    [HttpGet("pendientes")]
    [Permiso("finanzas.operativos", Accion.Ver)]
    public async Task<IActionResult> GetPendientes() => Ok(await _gastos.GetPendientesAsync());

    // --- Movimientos ---

    [HttpGet]
    [Permiso("finanzas.operativos", Accion.Ver)]
    public async Task<IActionResult> Listar([FromQuery] DateTime desde, [FromQuery] DateTime hasta) =>
        Ok(await _gastos.ListarAsync(desde, hasta));

    [HttpPost]
    [Permiso("finanzas.operativos", Accion.Crear)]
    public async Task<IActionResult> Crear([FromBody] MovimientoOperativoRequest request) =>
        Ok(await _gastos.CrearAsync(request, UsuarioId));

    [HttpPatch("{id:int}/anular")]
    [Permiso("finanzas.operativos", Accion.Anular)]
    public async Task<IActionResult> Anular(int id) => Ok(await _gastos.AnularAsync(id, UsuarioId));
}
