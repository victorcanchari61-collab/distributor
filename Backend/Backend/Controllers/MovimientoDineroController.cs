using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>El kardex del dinero: todo lo que entra y sale de las cajas y los bancos.</summary>
[ApiController]
[Route("api/movimientodinero")]
[Authorize]
public class MovimientoDineroController : ControllerBase
{
    private readonly IMovimientoDineroService _movimientos;

    public MovimientoDineroController(IMovimientoDineroService movimientos)
    {
        _movimientos = movimientos;
    }

    [HttpGet]
    [Permiso("finanzas.movimientos", Accion.Ver)]
    public async Task<IActionResult> Listar([FromQuery] DateTime desde, [FromQuery] DateTime hasta, [FromQuery] int? cuentaId) =>
        Ok(await _movimientos.ListarAsync(desde, hasta, cuentaId));

    [HttpGet("cuentas")]
    [Permiso("finanzas.movimientos", Accion.Ver)]
    public async Task<IActionResult> Cuentas() => Ok(await _movimientos.CuentasAsync());
}
