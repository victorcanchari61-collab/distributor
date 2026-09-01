using Backend.Dtos.Requests;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProveedorController : ControllerBase
{
    private readonly IProveedorService _proveedorService;

    public ProveedorController(IProveedorService proveedorService)
    {
        _proveedorService = proveedorService;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        return Ok(await _proveedorService.GetAllAsync());
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        return Ok(await _proveedorService.GetByIdAsync(id));
    }

    [HttpPost]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Create([FromBody] CreateProveedorRequest request)
    {
        var response = await _proveedorService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateProveedorRequest request)
    {
        return Ok(await _proveedorService.UpdateAsync(id, request));
    }

    /// <summary>Alta masiva desde archivo. Informa que paso con cada fila.</summary>
    [HttpPost("importar")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Importar([FromBody] ImportarProveedoresRequest request)
    {
        return Ok(await _proveedorService.ImportarAsync(request));
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Delete(int id)
    {
        await _proveedorService.DeleteAsync(id);
        return NoContent();
    }
}
