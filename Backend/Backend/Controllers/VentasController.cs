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

    /// <summary>Una página del listado, con búsqueda, filtros y orden resueltos en la base.</summary>
    [HttpPost("listar")]
    public async Task<IActionResult> Listar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _ventas.ListarPedidosAsync(consulta));

    /// <summary>Contadores del listado completo.</summary>
    [HttpGet("resumen")]
    public async Task<IActionResult> Resumen() => Ok(await _ventas.GetResumenPedidosAsync());

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

    /// <summary>Qué cambió en este pedido y sus líneas.</summary>
    [HttpGet("{id:int}/historial")]
    public async Task<IActionResult> Historial(int id) => Ok(await _ventas.GetHistorialPedidoAsync(id));
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

    /// <summary>Una página del listado, con búsqueda, filtros y orden resueltos en la base.</summary>
    [HttpPost("listar")]
    public async Task<IActionResult> Listar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _ventas.ListarNotasVentaAsync(consulta));

    /// <summary>Contadores del listado completo.</summary>
    [HttpGet("resumen")]
    public async Task<IActionResult> Resumen() => Ok(await _ventas.GetResumenNotasVentaAsync());

    /// <summary>Notas de venta a crédito con saldo pendiente: base de "Cuentas por cobrar".</summary>
    /// <summary>Una página de las cuentas por cobrar.</summary>
    [HttpPost("cuentasporcobrar/listar")]
    public async Task<IActionResult> ListarCuentasPorCobrar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _ventas.ListarCuentasPorCobrarAsync(consulta));

    /// <summary>Totales de todas las cuentas por cobrar.</summary>
    [HttpGet("cuentasporcobrar/resumen")]
    public async Task<IActionResult> ResumenCuentasPorCobrar() =>
        Ok(await _ventas.GetResumenCuentasPorCobrarAsync());

    [HttpGet("cuentasporcobrar")]
    public async Task<IActionResult> CuentasPorCobrar() => Ok(await _ventas.GetCuentasPorCobrarAsync());

    /// <summary>Venta directa, sin pedido previo: el stock sale al momento.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CrearNotaVentaRequest request)
    {
        var response = await _ventas.CrearNotaVentaAsync(request, UsuarioId);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    /// <summary>Corrige una venta ya confirmada: el stock se ajusta solo, según la diferencia.</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] CrearNotaVentaRequest request) =>
        Ok(await _ventas.ActualizarNotaVentaAsync(id, request, UsuarioId));

    [HttpPatch("{id:int}/anular")]
    public async Task<IActionResult> Anular(int id)
    {
        await _ventas.AnularNotaVentaAsync(id, UsuarioId);
        return NoContent();
    }

    /// <summary>Registra un abono contra el saldo pendiente de la nota.</summary>
    [HttpPost("{id:int}/pagos")]
    public async Task<IActionResult> RegistrarPago(int id, [FromBody] PagoVentaRequest request) =>
        Ok(await _ventas.RegistrarPagoAsync(id, request, UsuarioId));

    /// <summary>Corrige un pago ya registrado: método o monto.</summary>
    [HttpPut("{id:int}/pagos/{pagoId:int}")]
    public async Task<IActionResult> ActualizarPago(int id, int pagoId, [FromBody] PagoVentaRequest request) =>
        Ok(await _ventas.ActualizarPagoAsync(id, pagoId, request));

    /// <summary>Quita un pago registrado por error: su monto vuelve al saldo pendiente.</summary>
    [HttpDelete("{id:int}/pagos/{pagoId:int}")]
    public async Task<IActionResult> AnularPago(int id, int pagoId) =>
        Ok(await _ventas.AnularPagoAsync(id, pagoId));

    /// <summary>Los cobros que registró el usuario que hizo login, opcionalmente por rango de fechas.</summary>
    [HttpGet("miscobros")]
    public async Task<IActionResult> MisCobros([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _ventas.GetMisCobrosAsync(UsuarioId, desde, hasta));

    /// <summary>Una página de los cobros del usuario que hizo login.</summary>
    [HttpPost("miscobros/listar")]
    public async Task<IActionResult> ListarMisCobros(
        [FromBody] ConsultaTablaRequest consulta,
        [FromQuery] DateTime? desde,
        [FromQuery] DateTime? hasta) =>
        Ok(await _ventas.ListarMisCobrosAsync(consulta, UsuarioId, desde, hasta));

    /// <summary>Totales de esos cobros, sobre todo el rango.</summary>
    [HttpGet("miscobros/resumen")]
    public async Task<IActionResult> ResumenMisCobros(
        [FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _ventas.GetResumenCobrosAsync(UsuarioId, desde, hasta));

    /// <summary>Qué cambió en esta nota de venta: sobre todo anulaciones y movimientos de pago.</summary>
    [HttpGet("{id:int}/historial")]
    public async Task<IActionResult> Historial(int id) => Ok(await _ventas.GetHistorialNotaVentaAsync(id));
}
