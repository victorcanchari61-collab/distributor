using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// La Caja General, las cajas asignadas a vendedores/repartidores y las
/// cuentas bancarias — todas son CuentaFinanciera, una misma tabla. Ver vive
/// bajo `finanzas.caja` (Mi Caja/Caja General), `finanzas.cajas` (el
/// submódulo que las crea y asigna) o `finanzas.bancos`, según quién
/// pregunte. Crear/editar exige el permiso del submódulo dueño de esa
/// naturaleza: Cajas para NaturalezaCuenta.Caja, Bancos para el resto.
/// </summary>
[ApiController]
[Route("api/cuentafinanciera")]
[Authorize]
public class CuentaFinancieraController : ControllerBase
{
    private readonly ICuentaFinancieraService _cuentas;

    public CuentaFinancieraController(ICuentaFinancieraService cuentas)
    {
        _cuentas = cuentas;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    [PermisoAlguno("finanzas.caja:ver", "finanzas.cajas:ver", "finanzas.bancos:ver")]
    public async Task<IActionResult> GetAll() => Ok(await _cuentas.GetAllAsync());

    [HttpGet("{id:int}")]
    [PermisoAlguno("finanzas.caja:ver", "finanzas.cajas:ver", "finanzas.bancos:ver")]
    public async Task<IActionResult> GetById(int id) => Ok(await _cuentas.GetByIdAsync(id));

    [HttpGet("{id:int}/movimientos")]
    [PermisoAlguno("finanzas.caja:ver", "finanzas.cajas:ver", "finanzas.bancos:ver")]
    public async Task<IActionResult> Movimientos(
        int id, [FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _cuentas.MovimientosAsync(id, desde, hasta));

    [HttpPost]
    [PermisoAlguno("finanzas.cajas:crear", "finanzas.bancos:crear")]
    public async Task<IActionResult> Create([FromBody] CuentaFinancieraRequest request) =>
        Ok(await _cuentas.CreateAsync(request, UsuarioId));

    [HttpPut("{id:int}")]
    [PermisoAlguno("finanzas.cajas:editar", "finanzas.bancos:editar")]
    public async Task<IActionResult> Update(int id, [FromBody] CuentaFinancieraRequest request) =>
        Ok(await _cuentas.UpdateAsync(id, request));

    /// <summary>Crea la Bóveda de la empresa: la única caja sin responsable.</summary>
    [HttpPost("boveda")]
    [Permiso("finanzas.cajas", Accion.Crear)]
    public async Task<IActionResult> CrearBoveda([FromBody] CrearBovedaRequest request) =>
        Ok(await _cuentas.CrearBovedaAsync(request, UsuarioId));

    /// <summary>Mueve plata entre cuentas propias: depósito, sencillo, retiro.</summary>
    [HttpPost("transferir")]
    [PermisoAlguno("finanzas.movimientos:crear", "finanzas.cajas:editar")]
    public async Task<IActionResult> Transferir([FromBody] TransferenciaCuentasRequest request) =>
        Ok(new { salidaId = await _cuentas.TransferirEntreCuentasAsync(request, UsuarioId) });

    /// <summary>Anula una transferencia entre cuentas, dada cualquiera de sus mitades.</summary>
    [HttpPatch("transferencias/{movimientoId:int}/anular")]
    [PermisoAlguno("finanzas.movimientos:anular", "finanzas.cajas:editar")]
    public async Task<IActionResult> AnularTransferencia(int movimientoId)
    {
        await _cuentas.AnularTransferenciaAsync(movimientoId, UsuarioId);
        return NoContent();
    }
}
