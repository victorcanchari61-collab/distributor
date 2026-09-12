using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>Devoluciones de cliente: nacen de una nota de venta y se aprueban.</summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DevolucionController : ControllerBase
{
    private readonly IDevolucionService _devoluciones;

    public DevolucionController(IDevolucionService devoluciones)
    {
        _devoluciones = devoluciones;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    [Permiso("dms.devoluciones", Accion.Ver)]
    public async Task<IActionResult> GetAll([FromQuery] string? estado) =>
        Ok(await _devoluciones.GetAllAsync(estado));

    [HttpGet("resumen")]
    [Permiso("dms.devoluciones", Accion.Ver)]
    public async Task<IActionResult> Resumen() => Ok(await _devoluciones.GetResumenAsync());

    [HttpGet("{id:int}")]
    [Permiso("dms.devoluciones", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _devoluciones.GetAsync(id));

    /// <summary>Lo que todavía se puede devolver de una venta.</summary>
    [HttpGet("devolvible/{notaVentaId:int}")]
    [Permiso("dms.devoluciones", Accion.Ver)]
    public async Task<IActionResult> Devolvible(int notaVentaId) =>
        Ok(await _devoluciones.DevolvibleAsync(notaVentaId));

    [HttpPost]
    [Permiso("dms.devoluciones", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] DevolucionRequest request)
    {
        var creada = await _devoluciones.CrearAsync(request, UsuarioId);
        return CreatedAtAction(nameof(GetById), new { id = creada.Id }, creada);
    }

    /*
     * Aprobar y rechazar piden "confirmar", no "editar".
     *
     * Quien registra una devolucion en la calle no deberia poder aprobarsela:
     * son dos permisos distintos justamente para poder separar las dos manos.
     */

    [HttpPatch("{id:int}/aprobar")]
    [Permiso("dms.devoluciones", Accion.Confirmar)]
    public async Task<IActionResult> Aprobar(int id) =>
        Ok(await _devoluciones.AprobarAsync(id, UsuarioId));

    [HttpPatch("{id:int}/rechazar")]
    [Permiso("dms.devoluciones", Accion.Confirmar)]
    public async Task<IActionResult> Rechazar(int id, [FromBody] RechazarDevolucionRequest request) =>
        Ok(await _devoluciones.RechazarAsync(id, request.Motivo, UsuarioId));
}
