using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>Adelantos y préstamos al trabajador, que se descuentan en la planilla.</summary>
[ApiController]
[Route("api/adelanto")]
[Authorize]
public class AdelantoController : ControllerBase
{
    private readonly IAdelantoService _adelantos;

    public AdelantoController(IAdelantoService adelantos)
    {
        _adelantos = adelantos;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    [Permiso("rrhh.adelantos", Accion.Ver)]
    public async Task<IActionResult> Listar() => Ok(await _adelantos.ListarAsync());

    [HttpGet("resumen")]
    [Permiso("rrhh.adelantos", Accion.Ver)]
    public async Task<IActionResult> Resumen() => Ok(await _adelantos.ResumenAsync());

    /// <summary>Los empleados activos, con su sueldo y lo que deben: sin pedir permiso de Empleados.</summary>
    [HttpGet("empleados")]
    [Permiso("rrhh.adelantos", Accion.Ver)]
    public async Task<IActionResult> Empleados() => Ok(await _adelantos.EmpleadosAsync());

    /// <summary>De qué cuentas puede salir la plata: sin pedir permiso de Finanzas.</summary>
    [HttpGet("cuentas")]
    [Permiso("rrhh.adelantos", Accion.Ver)]
    public async Task<IActionResult> Cuentas() => Ok(await _adelantos.CuentasAsync());

    [HttpGet("{id:int}")]
    [Permiso("rrhh.adelantos", Accion.Ver)]
    public async Task<IActionResult> Get(int id) => Ok(await _adelantos.GetAsync(id));

    [HttpPost]
    [Permiso("rrhh.adelantos", Accion.Crear)]
    public async Task<IActionResult> Crear([FromBody] CrearAdelantoRequest request) =>
        Ok(await _adelantos.CrearAsync(request, UsuarioId));

    [HttpPut("{id:int}/plan")]
    [Permiso("rrhh.adelantos", Accion.Editar)]
    public async Task<IActionResult> CambiarPlan(int id, [FromBody] PlanAdelantoRequest request) =>
        Ok(await _adelantos.CambiarPlanAsync(id, request));

    [HttpPatch("{id:int}/anular")]
    [Permiso("rrhh.adelantos", Accion.Anular)]
    public async Task<IActionResult> Anular(int id) => Ok(await _adelantos.AnularAsync(id, UsuarioId));
}
