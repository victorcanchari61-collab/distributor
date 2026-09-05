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

    [HttpGet("entidades")]
    public async Task<IActionResult> GetEntidades() => Ok(await _auditoria.GetEntidadesAsync());
}
