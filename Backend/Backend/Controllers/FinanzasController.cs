using System.Security.Claims;
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
public class MetodoPagoController : ControllerBase
{
    private readonly IFinanzasService _finanzas;

    public MetodoPagoController(IFinanzasService finanzas)
    {
        _finanzas = finanzas;
    }

    [HttpGet]
    [Permiso("finanzas.metodospago", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _finanzas.GetMetodosPagoAsync());

    /// <summary>
    /// Los métodos activos, lo justo para elegir con cuál se cobra: nombre y
    /// tipo, sin datos de cuenta ni contadores.
    ///
    /// Lo pide quien entrega pedidos y cobra al recibir, que puede tener ese
    /// permiso sin poder ver ni editar el catálogo de Finanzas.
    /// </summary>
    [HttpGet("opciones")]
    [PermisoAlguno("finanzas.metodospago:ver", "fact.pedidos:confirmar", "fact.notaventa:cobrar", "finanzas.cobrar:cobrar")]
    public async Task<IActionResult> Opciones() =>
        Ok((await _finanzas.GetMetodosPagoAsync())
            .Where(m => m.Activo)
            .Select(m => new { m.Id, m.Nombre, m.Tipo }));

    [HttpGet("{id:int}")]
    [Permiso("finanzas.metodospago", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _finanzas.GetMetodoPagoAsync(id));

    [HttpPost]
    [Permiso("finanzas.metodospago", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateMetodoPagoRequest request)
    {
        var response = await _finanzas.CreateMetodoPagoAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("finanzas.metodospago", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateMetodoPagoRequest request) =>
        Ok(await _finanzas.UpdateMetodoPagoAsync(id, request));

    [HttpDelete("{id:int}")]
    [Permiso("finanzas.metodospago", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _finanzas.DeleteMetodoPagoAsync(id);
        return NoContent();
    }
}
