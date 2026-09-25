using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/asistencia")]
[Authorize]
public class AsistenciaController : ControllerBase
{
    private readonly IAsistenciaService _asistencia;
    private readonly IPermisoService _permisos;

    public AsistenciaController(IAsistenciaService asistencia, IPermisoService permisos)
    {
        _asistencia = asistencia;
        _permisos = permisos;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    [Permiso("rrhh.asistencia", Accion.Ver)]
    public async Task<IActionResult> Listar(
        [FromQuery] DateTime desde, [FromQuery] DateTime hasta, [FromQuery] int? empleadoId) =>
        Ok(await _asistencia.ListarAsync(desde, hasta, empleadoId));

    [HttpGet("resumen")]
    [Permiso("rrhh.asistencia", Accion.Ver)]
    public async Task<IActionResult> Resumen(
        [FromQuery] DateTime desde, [FromQuery] DateTime hasta, [FromQuery] int? empleadoId) =>
        Ok(await _asistencia.ResumenAsync(desde, hasta, empleadoId));

    [HttpPost]
    [Permiso("rrhh.asistencia", Accion.Crear)]
    public async Task<IActionResult> Crear([FromBody] CrearAsistenciaRequest request) =>
        Ok(await _asistencia.CrearAsync(request, UsuarioId));

    /// <summary>Pase de lista de un día. Corregir una marca que ya existía pide además "editar".</summary>
    [HttpPost("dia")]
    [Permiso("rrhh.asistencia", Accion.Crear)]
    public async Task<IActionResult> MarcarDia([FromBody] MarcarDiaAsistenciaRequest request)
    {
        var puedeCorregir = UsuarioId is int id && await _permisos.PuedeAsync(id, "rrhh.asistencia", Accion.Editar);
        return Ok(await _asistencia.MarcarDiaAsync(request, UsuarioId, puedeCorregir));
    }

    [HttpPut("{id:int}")]
    [Permiso("rrhh.asistencia", Accion.Editar)]
    public async Task<IActionResult> Editar(int id, [FromBody] EditarAsistenciaRequest request) =>
        Ok(await _asistencia.EditarAsync(id, request));

    [HttpPatch("{id:int}/anular")]
    [Permiso("rrhh.asistencia", Accion.Anular)]
    public async Task<IActionResult> Anular(int id) => Ok(await _asistencia.AnularAsync(id));
}
