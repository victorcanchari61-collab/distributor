using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
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
}
