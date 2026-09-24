using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// La Caja General y las cuentas bancarias. Ver/crear/editar vive bajo
/// `finanzas.bancos` — es donde tiene sentido dar de alta una cuenta nueva —
/// pero también se puede VER desde `finanzas.caja`, que solo necesita
/// consultar el saldo y los movimientos de la Caja General.
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

    [HttpGet]
    [PermisoAlguno("finanzas.caja:ver", "finanzas.bancos:ver")]
    public async Task<IActionResult> GetAll() => Ok(await _cuentas.GetAllAsync());

    [HttpGet("{id:int}")]
    [PermisoAlguno("finanzas.caja:ver", "finanzas.bancos:ver")]
    public async Task<IActionResult> GetById(int id) => Ok(await _cuentas.GetByIdAsync(id));

    [HttpGet("{id:int}/movimientos")]
    [PermisoAlguno("finanzas.caja:ver", "finanzas.bancos:ver")]
    public async Task<IActionResult> Movimientos(
        int id, [FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _cuentas.MovimientosAsync(id, desde, hasta));

    [HttpPost]
    [Permiso("finanzas.bancos", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CuentaFinancieraRequest request) =>
        Ok(await _cuentas.CreateAsync(request));

    [HttpPut("{id:int}")]
    [Permiso("finanzas.bancos", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] CuentaFinancieraRequest request) =>
        Ok(await _cuentas.UpdateAsync(id, request));
}
