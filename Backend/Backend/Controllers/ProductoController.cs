using Backend.Dtos.Requests;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProductoController : ControllerBase
{
    private readonly IProductoService _productoService;

    public ProductoController(IProductoService productoService)
    {
        _productoService = productoService;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(await _productoService.GetAllAsync());

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id) =>
        Ok(await _productoService.GetByIdAsync(id));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateProductoRequest request)
    {
        var response = await _productoService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateProductoRequest request) =>
        Ok(await _productoService.UpdateAsync(id, request));

    [HttpPatch("{id:int}/activar")]
    public async Task<IActionResult> Activar(int id) =>
        Ok(await _productoService.CambiarEstadoAsync(id, true));

    [HttpPatch("{id:int}/desactivar")]
    public async Task<IActionResult> Desactivar(int id) =>
        Ok(await _productoService.CambiarEstadoAsync(id, false));

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Delete(int id)
    {
        await _productoService.DeleteAsync(id);
        return NoContent();
    }

    // --- Presentaciones ---

    /// <summary>Agrega una forma de comprar o vender: saco de 50, caja x12.</summary>
    [HttpPost("{id:int}/presentaciones")]
    public async Task<IActionResult> AgregarPresentacion(
        int id, [FromBody] PresentacionRequest request) =>
        Ok(await _productoService.AgregarPresentacionAsync(id, request));

    [HttpPut("presentaciones/{presentacionId:int}")]
    public async Task<IActionResult> ActualizarPresentacion(
        int presentacionId, [FromBody] PresentacionRequest request) =>
        Ok(await _productoService.ActualizarPresentacionAsync(presentacionId, request));

    [HttpDelete("presentaciones/{presentacionId:int}")]
    public async Task<IActionResult> EliminarPresentacion(int presentacionId)
    {
        await _productoService.EliminarPresentacionAsync(presentacionId);
        return NoContent();
    }

    /// <summary>
    /// Cuanta unidad base mueve una cantidad en cierta presentacion. Deja
    /// comprobar la conversion sin registrar nada: 2 sacos de 50 -> 100 kg.
    /// </summary>
    [HttpGet("presentaciones/{presentacionId:int}/convertir")]
    public async Task<IActionResult> Convertir(
        int presentacionId, [FromQuery] decimal cantidad = 1m)
    {
        var enBase = await _productoService.AUnidadBaseAsync(presentacionId, cantidad);
        return Ok(new { presentacionId, cantidad, unidadBase = enBase });
    }
}
