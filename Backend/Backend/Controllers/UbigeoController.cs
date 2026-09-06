using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>Ubigeo oficial del Perú: departamento, provincia y distrito. Solo lectura.</summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UbigeoController : ControllerBase
{
    private readonly IUbigeoService _ubigeo;

    public UbigeoController(IUbigeoService ubigeo)
    {
        _ubigeo = ubigeo;
    }

    [HttpGet("departamentos")]
    public async Task<IActionResult> GetDepartamentos() => Ok(await _ubigeo.GetDepartamentosAsync());

    [HttpGet("provincias")]
    public async Task<IActionResult> GetProvincias([FromQuery] int? departamentoId) =>
        Ok(await _ubigeo.GetProvinciasAsync(departamentoId));

    [HttpGet("distritos")]
    public async Task<IActionResult> GetDistritos([FromQuery] int? provinciaId) =>
        Ok(await _ubigeo.GetDistritosAsync(provinciaId));
}
