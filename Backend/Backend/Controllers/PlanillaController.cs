using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>La planilla semanal de RR.HH.</summary>
[ApiController]
[Route("api/planilla")]
[Authorize]
public class PlanillaController : ControllerBase
{
    private readonly IPlanillaService _planillas;

    public PlanillaController(IPlanillaService planillas)
    {
        _planillas = planillas;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    /// <summary>La de la semana que contiene esa fecha. 204 si todavía no se armó.</summary>
    [HttpGet("semana")]
    [Permiso("rrhh.planilla", Accion.Ver)]
    public async Task<IActionResult> Semana([FromQuery] DateTime fecha)
    {
        var planilla = await _planillas.GetSemanaAsync(fecha);
        return planilla is null ? NoContent() : Ok(planilla);
    }

    [HttpGet]
    [Permiso("rrhh.planilla", Accion.Ver)]
    public async Task<IActionResult> Historial() => Ok(await _planillas.HistorialAsync());

    /// <summary>De qué cuentas puede salir el pago: sin pedir permiso de Finanzas.</summary>
    [HttpGet("cuentas")]
    [Permiso("rrhh.planilla", Accion.Ver)]
    public async Task<IActionResult> Cuentas() => Ok(await _planillas.CuentasAsync());

    [HttpPost("generar")]
    [Permiso("rrhh.planilla", Accion.Crear)]
    public async Task<IActionResult> Generar([FromBody] GenerarPlanillaRequest request) =>
        Ok(await _planillas.GenerarAsync(request.Semana, UsuarioId));

    [HttpPut("detalle/{detalleId:int}")]
    [Permiso("rrhh.planilla", Accion.Editar)]
    public async Task<IActionResult> Ajustar(int detalleId, [FromBody] AjustePlanillaRequest request) =>
        Ok(await _planillas.AjustarAsync(detalleId, request));

    [HttpPost("{id:int}/pagar")]
    [Permiso("rrhh.planilla", Accion.Crear)]
    public async Task<IActionResult> Pagar(int id, [FromBody] PagarPlanillaRequest request) =>
        Ok(await _planillas.PagarAsync(id, request, UsuarioId));

    [HttpPatch("{id:int}/anular")]
    [Permiso("rrhh.planilla", Accion.Anular)]
    public async Task<IActionResult> Anular(int id) => Ok(await _planillas.AnularAsync(id, UsuarioId));
}
