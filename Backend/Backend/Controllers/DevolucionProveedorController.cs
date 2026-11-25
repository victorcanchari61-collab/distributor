using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>Lo que se le devuelve a un proveedor de una compra, y el saldo a favor que eso deja.</summary>
[ApiController]
[Route("api/devolucion-proveedor")]
[Authorize]
public class DevolucionProveedorController : ControllerBase
{
    private readonly IDevolucionProveedorService _devoluciones;

    public DevolucionProveedorController(IDevolucionProveedorService devoluciones)
    {
        _devoluciones = devoluciones;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    [Permiso("compras.devoluciones", Accion.Ver)]
    public async Task<IActionResult> GetAll([FromQuery] int? compraId) =>
        Ok(await _devoluciones.GetAllAsync(compraId));

    [HttpGet("{id:int}")]
    [Permiso("compras.devoluciones", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _devoluciones.GetAsync(id));

    [HttpPost]
    [Permiso("compras.devoluciones", Accion.Crear)]
    public async Task<IActionResult> Crear([FromBody] CrearDevolucionProveedorRequest request)
    {
        var creada = await _devoluciones.CrearAsync(request, UsuarioId);
        return CreatedAtAction(nameof(GetById), new { id = creada.Id }, creada);
    }

    [HttpPatch("{id:int}/anular")]
    [Permiso("compras.devoluciones", Accion.Anular)]
    public async Task<IActionResult> Anular(int id) => Ok(await _devoluciones.AnularAsync(id, UsuarioId));

    // --- Saldo a favor ---

    /// <summary>Los proveedores que deben devolver plata. También lo mira Cuentas por pagar.</summary>
    [HttpGet("saldos")]
    [PermisoAlguno("compras.devoluciones:ver", "finanzas.pagar:ver")]
    public async Task<IActionResult> Saldos() => Ok(await _devoluciones.GetSaldosAsync());

    /// <summary>El saldo de un proveedor: lo pide quien paga una compra, para ofrecer usarlo.</summary>
    [HttpGet("saldos/{proveedorId:int}")]
    [PermisoAlguno("compras.devoluciones:ver", "compras.compras:cobrar", "finanzas.pagar:ver")]
    public async Task<IActionResult> Saldo(int proveedorId) =>
        Ok(new { proveedorId, saldo = await _devoluciones.GetSaldoAsync(proveedorId) });

    [HttpGet("saldos/{proveedorId:int}/movimientos")]
    [PermisoAlguno("compras.devoluciones:ver", "finanzas.pagar:ver")]
    public async Task<IActionResult> Movimientos(int proveedorId) =>
        Ok(await _devoluciones.GetMovimientosSaldoAsync(proveedorId));

    /// <summary>El proveedor devolvió plata del saldo a favor: entra a una caja o banco.</summary>
    [HttpPost("saldos/{proveedorId:int}/cobrar")]
    [Permiso("compras.devoluciones", Accion.Cobrar)]
    public async Task<IActionResult> Cobrar(int proveedorId, [FromBody] CobrarSaldoProveedorRequest request) =>
        Ok(await _devoluciones.CobrarSaldoAsync(proveedorId, request, UsuarioId));

    /// <summary>Anula un cobro registrado por error: la plata sale de la cuenta y vuelve al saldo.</summary>
    [HttpDelete("saldos/movimientos/{movimientoId:int}")]
    [Permiso("compras.devoluciones", Accion.Cobrar)]
    public async Task<IActionResult> AnularCobro(int movimientoId)
    {
        await _devoluciones.AnularCobroAsync(movimientoId, UsuarioId);
        return NoContent();
    }

    /// <summary>Paga (en parte o todo) una compra con el saldo a favor que se tiene con su proveedor.</summary>
    [HttpPost("/api/compra/{compraId:int}/saldo-favor")]
    [Permiso("compras.compras", Accion.Cobrar)]
    public async Task<IActionResult> AplicarSaldo(int compraId, [FromBody] AplicarSaldoProveedorRequest request) =>
        Ok(await _devoluciones.AplicarSaldoAsync(compraId, request, UsuarioId));
}
