using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// La Caja de quien está logueado: su propio dinero en la ruta. Cualquier
/// usuario ve y maneja la suya sin necesitar un permiso de Finanzas — es "lo
/// mío", igual que Mi Perfil. Un supervisor ve la de otro desde
/// `GET /cuentafinanciera` (necesita `finanzas.caja`/`finanzas.cajas`).
/// </summary>
[ApiController]
[Route("api/micaja")]
[Authorize]
public class MiCajaController : ControllerBase
{
    private readonly ICuentaFinancieraService _cuentas;
    private readonly IGastoOperativoService _gastos;
    private readonly ICierreCajaService _cierres;

    public MiCajaController(ICuentaFinancieraService cuentas, IGastoOperativoService gastos, ICierreCajaService cierres)
    {
        _cuentas = cuentas;
        _gastos = gastos;
        _cierres = cierres;
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
        // nadie postea a la caja de otro por aquí.
        request.CuentaFinancieraId = caja.Id;
        return Ok(await _gastos.CrearAsync(request, UsuarioId));
    }

    /// <summary>A qué cuentas puede entregar lo contado al cerrar.</summary>
    [HttpGet("destinos")]
    public async Task<IActionResult> Destinos() => Ok(await _cierres.DestinosAsync(UsuarioId));

    /// <summary>Cierra la caja: cuenta lo que tiene y lo entrega a la cuenta elegida.</summary>
    [HttpPost("cerrar")]
    public async Task<IActionResult> Cerrar([FromBody] CerrarCajaRequest request) =>
        Ok(await _cierres.CerrarAsync(UsuarioId, request));
}
