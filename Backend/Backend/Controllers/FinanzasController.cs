using System.Security.Claims;
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

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ArqueoController : ControllerBase
{
    private readonly IFinanzasService _finanzas;

    public ArqueoController(IFinanzasService finanzas)
    {
        _finanzas = finanzas;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    /// <summary>Lo cobrado y pagado en efectivo de un día, y su cierre si ya se registró.</summary>
    [HttpGet("resumen")]
    public async Task<IActionResult> Resumen([FromQuery] DateTime fecha) =>
        Ok(await _finanzas.GetResumenArqueoAsync(fecha));

    [HttpGet("historial")]
    public async Task<IActionResult> Historial() => Ok(await _finanzas.GetHistorialArqueoAsync());

    /// <summary>Registra el cierre de caja del día: reemplaza el que ya hubiera para esa fecha.</summary>
    [HttpPost]
    public async Task<IActionResult> Registrar([FromBody] RegistrarArqueoRequest request) =>
        Ok(await _finanzas.RegistrarArqueoAsync(request, UsuarioId));
}
