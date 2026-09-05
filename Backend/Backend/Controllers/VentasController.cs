using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PedidoController : ControllerBase
{
    private readonly IVentasService _ventas;

    public PedidoController(IVentasService ventas)
    {
        _ventas = ventas;
    }

    /// <summary>Quién registra el documento, tomado del token.</summary>
    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? estado) =>
        Ok(await _ventas.GetPedidosAsync(estado));

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id) => Ok(await _ventas.GetPedidoAsync(id));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CrearPedidoRequest request)
    {
        var response = await _ventas.CrearPedidoAsync(request, UsuarioId);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    /// <summary>Solo mientras está Pendiente: uno confirmado ya no se edita.</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] CrearPedidoRequest request) =>
        Ok(await _ventas.ActualizarPedidoAsync(id, request));

    /// <summary>Se despacha: cierra el pedido y crea la NotaVenta, que descuenta el stock.</summary>
    [HttpPatch("{id:int}/confirmar")]
    public async Task<IActionResult> Confirmar(int id, [FromBody] ConfirmarPedidoRequest request) =>
        Ok(await _ventas.ConfirmarPedidoAsync(id, request, UsuarioId));

    [HttpPatch("{id:int}/anular")]
    public async Task<IActionResult> Anular(int id)
    {
        await _ventas.AnularPedidoAsync(id);
        return NoContent();
    }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotaVentaController : ControllerBase
{
    private readonly IVentasService _ventas;

    public NotaVentaController(IVentasService ventas)
    {
        _ventas = ventas;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? estado) =>
        Ok(await _ventas.GetNotasVentaAsync(estado));

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id) => Ok(await _ventas.GetNotaVentaAsync(id));

    /// <summary>Notas de venta a crédito con saldo pendiente: base de "Cuentas por cobrar".</summary>
    [HttpGet("cuentasporcobrar")]
    public async Task<IActionResult> CuentasPorCobrar() => Ok(await _ventas.GetCuentasPorCobrarAsync());

    /// <summary>Venta directa, sin pedido previo: el stock sale al momento.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CrearNotaVentaRequest request)
    {
        var response = await _ventas.CrearNotaVentaAsync(request, UsuarioId);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPatch("{id:int}/anular")]
    public async Task<IActionResult> Anular(int id)
    {
        await _ventas.AnularNotaVentaAsync(id, UsuarioId);
        return NoContent();
    }

    /// <summary>Registra un abono contra el saldo pendiente de la nota.</summary>
    [HttpPost("{id:int}/pagos")]
    public async Task<IActionResult> RegistrarPago(int id, [FromBody] PagoVentaRequest request) =>
        Ok(await _ventas.RegistrarPagoAsync(id, request));
}
