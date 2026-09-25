using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Exceptions;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// La Caja de quien está logueado: su propio dinero en la ruta. Cualquier
/// usuario ve y maneja la suya sin necesitar un permiso de Finanzas — es "lo
/// mío", igual que Mi Perfil. Un supervisor ve la de otro desde
/// `GET /cuentafinanciera` (necesita `finanzas.caja`/`finanzas.bancos`).
/// </summary>
[ApiController]
[Route("api/micaja")]
[Authorize]
public class MiCajaController : ControllerBase
{
    private readonly ICuentaFinancieraService _cuentas;
    private readonly IGastoOperativoService _gastos;
    private readonly IArqueoService _arqueo;

    public MiCajaController(ICuentaFinancieraService cuentas, IGastoOperativoService gastos, IArqueoService arqueo)
    {
        _cuentas = cuentas;
        _gastos = gastos;
        _arqueo = arqueo;
    }

    private int UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
            ? id
            : throw new UnauthorizedAccessException("No se pudo identificar al usuario");

    [HttpGet]
    public async Task<IActionResult> Mia()
    {
        var caja = await _cuentas.ExigirCajaUsuarioAsync(UsuarioId);
        return Ok(await _cuentas.GetByIdAsync(caja.Id));
    }

    [HttpGet("movimientos")]
    public async Task<IActionResult> Movimientos([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta)
    {
        var caja = await _cuentas.ExigirCajaUsuarioAsync(UsuarioId);
        return Ok(await _cuentas.MovimientosAsync(caja.Id, desde, hasta));
    }

    /// <summary>Un ingreso o egreso libre: no hace falta que sea una venta ni un gasto de ruta.</summary>
    [HttpPost("movimiento")]
    public async Task<IActionResult> RegistrarMovimiento([FromBody] MovimientoOperativoRequest request)
    {
        var caja = await _cuentas.ExigirCajaUsuarioAsync(UsuarioId);
        // La cuenta la decide el servidor: nunca la que venga en el body — así
        // nadie postea a la caja de otro ni a la Caja General por aquí.
        request.CuentaFinancieraId = caja.Id;
        return Ok(await _gastos.CrearAsync(request, UsuarioId));
    }

    /// <summary>
    /// Cierra el día: cuenta lo que tiene físico, lo compara contra el saldo
    /// de su Caja, y liquida esa plata a la Caja General.
    /// </summary>
    [HttpPost("cerrar")]
    public async Task<IActionResult> Cerrar([FromBody] RegistrarArqueoRequest request)
    {
        request.UsuarioId = UsuarioId;
        return Ok(await _arqueo.RegistrarAsync(request, UsuarioId));
    }
}
