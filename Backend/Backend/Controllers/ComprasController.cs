using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class OrdenCompraController : ControllerBase
{
    private readonly IComprasService _compras;

    public OrdenCompraController(IComprasService compras)
    {
        _compras = compras;
    }

    /// <summary>Quién registra el documento, tomado del token.</summary>
    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? estado) =>
        Ok(await _compras.GetOrdenesAsync(estado));

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id) => Ok(await _compras.GetOrdenAsync(id));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CrearOrdenCompraRequest request)
    {
        var response = await _compras.CrearOrdenAsync(request, UsuarioId);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    /// <summary>Solo mientras está Pendiente: una confirmada ya no se edita.</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] CrearOrdenCompraRequest request) =>
        Ok(await _compras.ActualizarOrdenAsync(id, request));

    /// <summary>El proveedor aceptó despachar: cierra la orden y crea la Compra.</summary>
    [HttpPatch("{id:int}/confirmar")]
    public async Task<IActionResult> Confirmar(int id) => Ok(await _compras.ConfirmarOrdenAsync(id));

    [HttpPatch("{id:int}/anular")]
    public async Task<IActionResult> Anular(int id)
    {
        await _compras.AnularOrdenAsync(id);
        return NoContent();
    }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CompraController : ControllerBase
{
    private readonly IComprasService _compras;

    public CompraController(IComprasService compras)
    {
        _compras = compras;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? estado) =>
        Ok(await _compras.GetComprasAsync(estado));

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id) => Ok(await _compras.GetCompraAsync(id));

    /// <summary>Compras a crédito con saldo pendiente: base de "Cuentas por pagar".</summary>
    [HttpGet("cuentasporpagar")]
    public async Task<IActionResult> CuentasPorPagar() => Ok(await _compras.GetCuentasPorPagarAsync());

    /// <summary>Compra directa, sin orden previa: al contado, en el momento.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CrearCompraRequest request)
    {
        var response = await _compras.CrearCompraAsync(request, UsuarioId);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    /// <summary>Solo si nada se ha recibido: si ya hay recepciones, ya no se edita.</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] CrearCompraRequest request) =>
        Ok(await _compras.ActualizarCompraAsync(id, request));

    /// <summary>Solo si nada se ha recibido: si ya hay recepciones, se anulan ellas.</summary>
    [HttpPatch("{id:int}/anular")]
    public async Task<IActionResult> Anular(int id)
    {
        await _compras.AnularCompraAsync(id);
        return NoContent();
    }

    /// <summary>Registra un abono contra el saldo pendiente de la compra.</summary>
    [HttpPost("{id:int}/pagos")]
    public async Task<IActionResult> RegistrarPago(int id, [FromBody] PagoCompraRequest request) =>
        Ok(await _compras.RegistrarPagoAsync(id, request));
}
