using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Días no laborables (quien los trabaja cobra doble). Vive bajo el mismo permiso que
/// Asistencia: se gestiona desde ahí mismo, no tiene entrada propia en el menú.
/// </summary>
[ApiController]
[Route("api/feriado")]
[Authorize]
public class FeriadoController : ControllerBase
{
    private readonly IFeriadoService _feriados;

    public FeriadoController(IFeriadoService feriados)
    {
        _feriados = feriados;
    }

    [HttpGet]
    [Permiso("rrhh.asistencia", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _feriados.GetAllAsync());

    [HttpPost]
    [Permiso("rrhh.asistencia", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] FeriadoRequest request) =>
        Ok(await _feriados.CreateAsync(request));

    [HttpPut("{id:int}")]
    [Permiso("rrhh.asistencia", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] FeriadoRequest request) =>
        Ok(await _feriados.UpdateAsync(id, request));

    [HttpDelete("{id:int}")]
    [Permiso("rrhh.asistencia", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _feriados.DeleteAsync(id);
        return NoContent();
    }
}
