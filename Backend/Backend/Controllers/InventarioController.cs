using System.Security.Claims;
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
    public async Task<IActionResult> Create([FromBody] CreateAlmacenRequest request)
    {
        var response = await _inventario.CreateAlmacenAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
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
public class MotivoController : ControllerBase
{
    private readonly IInventarioService _inventario;

    public MotivoController(IInventarioService inventario)
    {
        _inventario = inventario;
    }

    /// <summary>
    /// Todos los motivos. Los del sistema vienen marcados: la pantalla no los
    /// ofrece al hacer un ajuste.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(await _inventario.GetMotivosAsync());

    [HttpPost]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Create([FromBody] CreateMotivoRequest request) =>
        Ok(await _inventario.CreateMotivoAsync(request));

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateMotivoRequest request) =>
        Ok(await _inventario.UpdateMotivoAsync(id, request));

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Delete(int id)
    {
        await _inventario.DeleteMotivoAsync(id);
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

    /// <summary>Quién registra el documento, tomado del token.</summary>
    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    /// <summary>Stock de todos los productos. Sin almacén, suma todos.</summary>
    [HttpGet("stock")]
    public async Task<IActionResult> Stock([FromQuery] int? almacenId) =>
        Ok(await _inventario.GetStockAsync(almacenId));

    /// <summary>Stock y capas de costo de un producto.</summary>
    [HttpGet("stock/{productoId:int}")]
    public async Task<IActionResult> StockProducto(int productoId, [FromQuery] int? almacenId) =>
        Ok(await _inventario.GetStockProductoAsync(productoId, almacenId));

    /// <summary>Kardex: todo lo que entró y salió, con el saldo que dejó.</summary>
    [HttpGet("kardex")]
    public async Task<IActionResult> Kardex(
        [FromQuery] int? productoId,
        [FromQuery] int? almacenId,
        [FromQuery] DateTime? desde,
        [FromQuery] DateTime? hasta) =>
        Ok(await _inventario.GetKardexAsync(productoId, almacenId, desde, hasta));

    // --- Ajustes ---

    [HttpGet("ajustes")]
    public async Task<IActionResult> Ajustes() => Ok(await _inventario.GetDocumentosAsync());

    [HttpGet("ajustes/{id:int}")]
    public async Task<IActionResult> Ajuste(int id) => Ok(await _inventario.GetDocumentoAsync(id));

    /// <summary>Registra el ajuste y mueve el stock. Todo o nada.</summary>
    [HttpPost("ajustes")]
    public async Task<IActionResult> CrearAjuste([FromBody] CrearAjusteRequest request) =>
        Ok(await _inventario.CrearAjusteAsync(request, UsuarioId));

    /// <summary>Crea el documento espejo que deshace otro. No borra nada.</summary>
    [HttpPatch("ajustes/{id:int}/anular")]
    public async Task<IActionResult> Anular(int id) =>
        Ok(await _inventario.AnularAsync(id, UsuarioId));
}
