using Backend.Dtos.Requests;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AlmacenController : ControllerBase
{
    private readonly IInventarioService _inventario;

    public AlmacenController(IInventarioService inventario)
    {
        _inventario = inventario;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(await _inventario.GetAlmacenesAsync());

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id) => Ok(await _inventario.GetAlmacenAsync(id));

    [HttpPost]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Create([FromBody] CreateAlmacenRequest request)
    {
        var response = await _inventario.CreateAlmacenAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateAlmacenRequest request) =>
        Ok(await _inventario.UpdateAlmacenAsync(id, request));

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Delete(int id)
    {
        await _inventario.DeleteAlmacenAsync(id);
        return NoContent();
    }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class InventarioController : ControllerBase
{
    private readonly IInventarioService _inventario;

    public InventarioController(IInventarioService inventario)
    {
        _inventario = inventario;
    }

    /// <summary>Stock, costos y capas de un producto.</summary>
    [HttpGet("producto/{productoId:int}")]
    public async Task<IActionResult> Stock(int productoId, [FromQuery] int? almacenId) =>
        Ok(await _inventario.GetStockAsync(productoId, almacenId));

    /// <summary>
    /// Entrada de mercadería con su costo: saldo inicial, compra o ajuste.
    /// Crea una capa nueva, sin tocar las anteriores.
    /// </summary>
    [HttpPost("entrada")]
    public async Task<IActionResult> Entrada([FromBody] EntradaRequest request) =>
        Ok(await _inventario.RegistrarEntradaAsync(request));

    /// <summary>
    /// Salida de mercadería. Consume las capas más antiguas y responde cuánto
    /// costó lo que salió.
    /// </summary>
    [HttpPost("salida")]
    public async Task<IActionResult> Salida([FromBody] SalidaRequest request) =>
        Ok(await _inventario.RegistrarSalidaAsync(request));

    /// <summary>Lo mismo que salida pero sin tocar el stock: para ver el margen.</summary>
    [HttpPost("simular-salida")]
    public async Task<IActionResult> Simular([FromBody] SalidaRequest request) =>
        Ok(await _inventario.SimularSalidaAsync(request));
}
