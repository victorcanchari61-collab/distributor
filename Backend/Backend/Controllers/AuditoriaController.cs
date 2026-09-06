using Backend.Dtos.Requests;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

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
    public async Task<IActionResult> Listar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _auditoria.ListarAsync(consulta));

    /// <summary>Contadores y valores de filtro de toda la bitácora.</summary>
    [HttpGet("resumen")]
    public async Task<IActionResult> Resumen() => Ok(await _auditoria.GetResumenAsync());

    [HttpGet("entidades")]
    public async Task<IActionResult> GetEntidades() => Ok(await _auditoria.GetEntidadesAsync());
}
