using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Consulta de documentos en linea. El frontend llama aqui y nunca al
/// proveedor externo, para no exponer el token.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ConsultaController : ControllerBase
{
    private readonly IConsultaService _consultaService;

    public ConsultaController(IConsultaService consultaService)
    {
        _consultaService = consultaService;
    }

    /// <summary>Datos de la empresa en SUNAT.</summary>
    [HttpGet("ruc/{ruc}")]
    public async Task<IActionResult> Ruc(string ruc)
    {
        return Ok(await _consultaService.ConsultarRucAsync(ruc));
    }

    /// <summary>Datos de la persona en RENIEC.</summary>
    [HttpGet("dni/{dni}")]
    public async Task<IActionResult> Dni(string dni)
    {
        return Ok(await _consultaService.ConsultarDniAsync(dni));
    }
}
