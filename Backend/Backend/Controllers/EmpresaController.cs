using Backend.Dtos.Requests;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class EmpresaController : ControllerBase
{
    private readonly IEmpresaService _empresaService;

    public EmpresaController(IEmpresaService empresaService)
    {
        _empresaService = empresaService;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        return Ok(await _empresaService.GetAllAsync());
    }

    /// <summary>Empresa con la que opera el sistema.</summary>
    [HttpGet("activa")]
    public async Task<IActionResult> GetActiva()
    {
        return Ok(await _empresaService.GetActivaAsync());
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        return Ok(await _empresaService.GetByIdAsync(id));
    }

    [HttpPost]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Create([FromBody] CreateEmpresaRequest request)
    {
        var response = await _empresaService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateEmpresaRequest request)
    {
        return Ok(await _empresaService.UpdateAsync(id, request));
    }

    /// <summary>Activa una empresa y desactiva la que lo estuviera.</summary>
    [HttpPatch("{id:int}/activar")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Activar(int id)
    {
        return Ok(await _empresaService.ActivarAsync(id));
    }

    /// <summary>Retira una empresa sin eliminarla.</summary>
    [HttpPatch("{id:int}/deshabilitar")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Deshabilitar(int id)
    {
        return Ok(await _empresaService.CambiarHabilitacionAsync(id, false));
    }

    /// <summary>Vuelve a poner disponible una empresa retirada.</summary>
    [HttpPatch("{id:int}/habilitar")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Habilitar(int id)
    {
        return Ok(await _empresaService.CambiarHabilitacionAsync(id, true));
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Delete(int id)
    {
        await _empresaService.DeleteAsync(id);
        return NoContent();
    }
}
