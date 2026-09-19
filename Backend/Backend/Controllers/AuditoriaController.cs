using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AuditoriaController : ControllerBase
{
    private readonly IAuditoriaService _auditoria;

    public AuditoriaController(IAuditoriaService auditoria)
    {
        _auditoria = auditoria;
    }

    [HttpGet]
    [Permiso("config.auditoria", Accion.Ver)]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? entidad,
        [FromQuery] string? accion,
        [FromQuery] int? usuarioId,
        [FromQuery] DateTime? desde,
        [FromQuery] DateTime? hasta) =>
        Ok(await _auditoria.GetAsync(entidad, accion, usuarioId, desde, hasta));

    /// <summary>
    /// Una página del listado. Va por POST porque los filtros son una lista de
    /// objetos: armarlos en la query string obligaría a inventar una
    /// codificación propia y a mantenerla en los dos lados.
    /// </summary>
    [HttpPost("listar")]
    [Permiso("config.auditoria", Accion.Ver)]
    public async Task<IActionResult> Listar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _auditoria.ListarAsync(consulta));

    /// <summary>
    /// Depuración masiva: borra todo lo que el buscador y los filtros de la
    /// tabla dejan a la vista. Recibe la misma consulta que <c>listar</c> para
    /// que borre exactamente lo que la persona estaba viendo.
    /// </summary>
    [HttpPost("eliminar")]
    [Permiso("config.auditoria", Accion.Eliminar)]
    public async Task<IActionResult> Eliminar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(new { eliminados = await _auditoria.EliminarAsync(consulta, UsuarioId) });

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    /// <summary>Contadores y valores de filtro de toda la bitácora.</summary>
    [HttpGet("resumen")]
    [Permiso("config.auditoria", Accion.Ver)]
    public async Task<IActionResult> Resumen() => Ok(await _auditoria.GetResumenAsync());

    [HttpGet("entidades")]
    [Permiso("config.auditoria", Accion.Ver)]
    public async Task<IActionResult> GetEntidades() => Ok(await _auditoria.GetEntidadesAsync());
}
