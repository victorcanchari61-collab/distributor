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
public class MercadoController : ControllerBase
{
    private readonly IMercadoService _mercados;

    public MercadoController(IMercadoService mercados)
    {
        _mercados = mercados;
    }

    [HttpGet]
    [Permiso("tms.mercados", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _mercados.GetAllAsync());

    [HttpGet("{id:int}")]
    [Permiso("tms.mercados", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _mercados.GetByIdAsync(id));

    [HttpPost]
    [Permiso("tms.mercados", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateMercadoRequest request)
    {
        var response = await _mercados.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("tms.mercados", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateMercadoRequest request) =>
        Ok(await _mercados.UpdateAsync(id, request));

    [HttpDelete("{id:int}")]
    [Permiso("tms.mercados", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _mercados.DeleteAsync(id);
        return NoContent();
    }
}
