using Backend.Dtos.Requests;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class RutaController : ControllerBase
{
    private readonly IRutaService _rutas;

    public RutaController(IRutaService rutas)
    {
        _rutas = rutas;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(await _rutas.GetAllAsync());

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id) => Ok(await _rutas.GetByIdAsync(id));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateRutaRequest request)
    {
        var response = await _rutas.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateRutaRequest request) =>
        Ok(await _rutas.UpdateAsync(id, request));

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Delete(int id)
    {
        await _rutas.DeleteAsync(id);
        return NoContent();
    }
}
