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
public class EmpleadoController : ControllerBase
{
    private readonly IEmpleadoService _empleados;

    public EmpleadoController(IEmpleadoService empleados)
    {
        _empleados = empleados;
    }

    [HttpGet]
    [Permiso("rrhh.empleados", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _empleados.GetAllAsync());

    /// <summary>
    /// Los empleados para elegir uno al crear un usuario.
    ///
    /// Lo puede leer quien administra usuarios aunque no tenga el maestro de Empleados: si no, no
    /// podría enlazar la cuenta con su ficha.
    /// </summary>
    [HttpGet("opciones")]
    [PermisoAlguno("rrhh.empleados:ver", "config.usuarios:ver")]
    public async Task<IActionResult> Opciones() => Ok(await _empleados.OpcionesAsync());

    [HttpGet("{id:int}")]
    [Permiso("rrhh.empleados", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _empleados.GetByIdAsync(id));

    [HttpPost]
    [Permiso("rrhh.empleados", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateEmpleadoRequest request)
    {
        var response = await _empleados.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("rrhh.empleados", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateEmpleadoRequest request) =>
        Ok(await _empleados.UpdateAsync(id, request));

    [HttpPatch("{id:int}/activar")]
    [Permiso("rrhh.empleados", Accion.Editar)]
    public async Task<IActionResult> Activar(int id) => Ok(await _empleados.CambiarEstadoAsync(id, true));

    /// <summary>Desactiva sin borrar: el que se fue conserva su historial.</summary>
    [HttpPatch("{id:int}/desactivar")]
    [Permiso("rrhh.empleados", Accion.Editar)]
    public async Task<IActionResult> Desactivar(int id) => Ok(await _empleados.CambiarEstadoAsync(id, false));

    [HttpDelete("{id:int}")]
    [Permiso("rrhh.empleados", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _empleados.DeleteAsync(id);
        return NoContent();
    }
}
