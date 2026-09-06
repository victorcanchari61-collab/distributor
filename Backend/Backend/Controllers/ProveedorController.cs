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
public class ProveedorController : ControllerBase
{
    private readonly IProveedorService _proveedorService;

    public ProveedorController(IProveedorService proveedorService)
    {
        _proveedorService = proveedorService;
    }

    [HttpGet]
    [Permiso("maestros.proveedores", Accion.Ver)]
    public async Task<IActionResult> GetAll()
    {
        return Ok(await _proveedorService.GetAllAsync());
    }

    [HttpGet("{id:int}")]
    [Permiso("maestros.proveedores", Accion.Ver)]
    public async Task<IActionResult> GetById(int id)
    {
        return Ok(await _proveedorService.GetByIdAsync(id));
    }

    [HttpPost]
    [Permiso("maestros.proveedores", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateProveedorRequest request)
    {
        var response = await _proveedorService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("maestros.proveedores", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateProveedorRequest request)
    {
        return Ok(await _proveedorService.UpdateAsync(id, request));
    }

    /// <summary>Alta masiva desde archivo. Informa que paso con cada fila.</summary>
    [HttpPost("importar")]
    [Permiso("maestros.proveedores", Accion.Importar)]
    public async Task<IActionResult> Importar([FromBody] ImportarProveedoresRequest request)
    {
        return Ok(await _proveedorService.ImportarAsync(request));
    }

    /// <summary>Activa el registro.</summary>
    [HttpPatch("{id:int}/activar")]
    [Permiso("maestros.proveedores", Accion.Editar)]
    public async Task<IActionResult> Activar(int id)
    {
        return Ok(await _proveedorService.CambiarEstadoAsync(id, true));
    }

    /// <summary>Desactiva sin borrar: deja de usarse pero conserva su historial.</summary>
    [HttpPatch("{id:int}/desactivar")]
    [Permiso("maestros.proveedores", Accion.Editar)]
    public async Task<IActionResult> Desactivar(int id)
    {
        return Ok(await _proveedorService.CambiarEstadoAsync(id, false));
    }

    [HttpDelete("{id:int}")]
    [Permiso("maestros.proveedores", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _proveedorService.DeleteAsync(id);
        return NoContent();
    }
}
