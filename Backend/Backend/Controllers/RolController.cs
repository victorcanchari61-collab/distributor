using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class RolController : ControllerBase
{
    private readonly IRolService _rolService;

    public RolController(IRolService rolService)
    {
        _rolService = rolService;
    }

    [HttpGet]
    [Permiso("config.roles", Accion.Ver)]
    public async Task<IActionResult> GetAll()
    {
        return Ok(await _rolService.GetAllAsync());
    }

    [HttpGet("{id:int}")]
    [Permiso("config.roles", Accion.Ver)]
    public async Task<IActionResult> GetById(int id)
    {
        return Ok(await _rolService.GetByIdAsync(id));
    }

    [HttpPost]
    [Permiso("config.roles", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateRolRequest request)
    {
        var response = await _rolService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("config.roles", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateRolRequest request)
    {
        return Ok(await _rolService.UpdateAsync(id, request));
    }

    /// <summary>Guarda la matriz de accesos del rol.</summary>
    [HttpPut("{id:int}/permisos")]
    [Permiso("config.accesos", Accion.Editar)]
    public async Task<IActionResult> UpdatePermisos(int id, [FromBody] UpdatePermisosRequest request)
    {
        return Ok(await _rolService.UpdatePermisosAsync(id, request));
    }

    [HttpDelete("{id:int}")]
    [Permiso("config.roles", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _rolService.DeleteAsync(id);
        return NoContent();
    }
}
