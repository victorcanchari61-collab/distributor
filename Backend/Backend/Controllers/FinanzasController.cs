using Backend.Dtos.Requests;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MetodoPagoController : ControllerBase
{
    private readonly IFinanzasService _finanzas;

    public MetodoPagoController(IFinanzasService finanzas)
    {
        _finanzas = finanzas;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(await _finanzas.GetMetodosPagoAsync());

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id) => Ok(await _finanzas.GetMetodoPagoAsync(id));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateMetodoPagoRequest request)
    {
        var response = await _finanzas.CreateMetodoPagoAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateMetodoPagoRequest request) =>
        Ok(await _finanzas.UpdateMetodoPagoAsync(id, request));

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Delete(int id)
    {
        await _finanzas.DeleteMetodoPagoAsync(id);
        return NoContent();
    }
}
