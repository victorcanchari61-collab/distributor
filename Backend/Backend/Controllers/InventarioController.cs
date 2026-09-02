using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Models;
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
    public async Task<IActionResult> Ajustes() =>
        Ok(await _inventario.GetDocumentosAsync(TipoDocumentoInventario.Ajuste));

    [HttpGet("ajustes/{id:int}")]
    public async Task<IActionResult> Ajuste(int id) => Ok(await _inventario.GetDocumentoAsync(id));

    /// <summary>Registra el ajuste y mueve el stock. Todo o nada.</summary>
    [HttpPost("ajustes")]
    public async Task<IActionResult> CrearAjuste([FromBody] CrearAjusteRequest request) =>
        Ok(await _inventario.CrearAjusteAsync(request, UsuarioId));

    /// <summary>
    /// Crea el documento espejo que deshace otro (ajuste o transferencia). No
    /// borra nada: el historial queda entero.
    /// </summary>
    [HttpPatch("ajustes/{id:int}/anular")]
    public async Task<IActionResult> Anular(int id) =>
        Ok(await _inventario.AnularAsync(id, UsuarioId));

    // --- Transferencias ---

    [HttpGet("transferencias")]
    public async Task<IActionResult> Transferencias() =>
        Ok(await _inventario.GetDocumentosAsync(TipoDocumentoInventario.Transferencia));

    [HttpGet("transferencias/{id:int}")]
    public async Task<IActionResult> Transferencia(int id) =>
        Ok(await _inventario.GetDocumentoAsync(id));

    /// <summary>Mueve mercadería entre dos almacenes propios. El costo viaja con ella.</summary>
    [HttpPost("transferencias")]
    public async Task<IActionResult> CrearTransferencia([FromBody] CrearTransferenciaRequest request) =>
        Ok(await _inventario.CrearTransferenciaAsync(request, UsuarioId));

    // --- Prestamos ---

    [HttpGet("prestamos")]
    public async Task<IActionResult> Prestamos() => Ok(await _inventario.GetPrestamosAsync());

    [HttpGet("prestamos/{id:int}")]
    public async Task<IActionResult> Prestamo(int id) => Ok(await _inventario.GetPrestamoAsync(id));

    /// <summary>Registra el préstamo: sale mercadería propia o entra la de un tercero.</summary>
    [HttpPost("prestamos")]
    public async Task<IActionResult> CrearPrestamo([FromBody] CrearPrestamoRequest request) =>
        Ok(await _inventario.CrearPrestamoAsync(request, UsuarioId));

    /// <summary>Registra una devolución, total o parcial, de un préstamo.</summary>
    [HttpPost("prestamos/{id:int}/devolucion")]
    public async Task<IActionResult> DevolverPrestamo(
        int id, [FromBody] DevolverPrestamoRequest request) =>
        Ok(await _inventario.DevolverPrestamoAsync(id, request, UsuarioId));
}
