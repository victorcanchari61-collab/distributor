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

    /// <summary>Una página del listado, con búsqueda, filtros y orden resueltos en la base.</summary>
    [HttpPost("listar")]
    public async Task<IActionResult> Listar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _compras.ListarOrdenesAsync(consulta));

    /// <summary>Contadores del listado completo.</summary>
    [HttpGet("resumen")]
    public async Task<IActionResult> Resumen() => Ok(await _compras.GetResumenOrdenesAsync());

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

    /// <summary>Una página del listado, con búsqueda, filtros y orden resueltos en la base.</summary>
    [HttpPost("listar")]
    public async Task<IActionResult> Listar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _compras.ListarComprasAsync(consulta));

    /// <summary>Contadores del listado completo.</summary>
    [HttpGet("resumen")]
    public async Task<IActionResult> Resumen() => Ok(await _compras.GetResumenComprasAsync());

    /// <summary>Las compras que todavía esperan mercadería: alimenta el modal de recepción.</summary>
    [HttpGet("abiertas")]
    public async Task<IActionResult> Abiertas() => Ok(await _compras.GetComprasAbiertasAsync());

    /// <summary>Compras a crédito con saldo pendiente: base de "Cuentas por pagar".</summary>
    /// <summary>Una página de las cuentas por pagar.</summary>
    [HttpPost("cuentasporpagar/listar")]
    public async Task<IActionResult> ListarCuentasPorPagar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _compras.ListarCuentasPorPagarAsync(consulta));

    /// <summary>Totales de todas las cuentas por pagar.</summary>
    [HttpGet("cuentasporpagar/resumen")]
    public async Task<IActionResult> ResumenCuentasPorPagar() =>
        Ok(await _compras.GetResumenCuentasPorPagarAsync());

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
        Ok(await _compras.RegistrarPagoAsync(id, request, UsuarioId));

    /// <summary>Corrige un pago ya registrado: método o monto.</summary>
    [HttpPut("{id:int}/pagos/{pagoId:int}")]
    public async Task<IActionResult> ActualizarPago(int id, int pagoId, [FromBody] PagoCompraRequest request) =>
        Ok(await _compras.ActualizarPagoAsync(id, pagoId, request));

    /// <summary>Quita un pago registrado por error: su monto vuelve al saldo pendiente.</summary>
    [HttpDelete("{id:int}/pagos/{pagoId:int}")]
    public async Task<IActionResult> AnularPago(int id, int pagoId) =>
        Ok(await _compras.AnularPagoAsync(id, pagoId));
}
