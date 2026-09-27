using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>La gestión de los cierres de caja de todos los trabajadores. El cierre propio se hace en Mi Caja.</summary>
[ApiController]
[Route("api/cierrecaja")]
[Authorize]
public class CierreCajaController : ControllerBase
{
    private readonly ICierreCajaService _cierres;
    private readonly ICobroDigitalService _cobros;

    public CierreCajaController(ICierreCajaService cierres, ICobroDigitalService cobros)
    {
        _cierres = cierres;
        _cobros = cobros;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    [Permiso("finanzas.cierres", Accion.Ver)]
    public async Task<IActionResult> Listar([FromQuery] DateTime desde, [FromQuery] DateTime hasta) =>
        Ok(await _cierres.ListarAsync(desde, hasta));

    [HttpPatch("{id:int}/anular")]
    [Permiso("finanzas.cierres", Accion.Anular)]
    public async Task<IActionResult> Anular(int id) => Ok(await _cierres.AnularAsync(id, UsuarioId));

    /*
     * Los cobros por Yape, Plin o transferencia no se cuentan en el cierre —esa
     * plata no pasa por la caja—, así que se cuadran aquí: se buscan en el
     * banco por su número de operación.
     */

    [HttpGet("cobrosdigitales")]
    [Permiso("finanzas.cierres", Accion.Ver)]
    public async Task<IActionResult> CobrosDigitales([FromQuery] DateTime desde, [FromQuery] DateTime hasta) =>
        Ok(await _cobros.ListarAsync(desde, hasta));

    [HttpPatch("cobrosdigitales/{pagoId:int}/verificar")]
    [Permiso("finanzas.cierres", Accion.Confirmar)]
    public async Task<IActionResult> Verificar(int pagoId) => Ok(await _cobros.VerificarAsync(pagoId, UsuarioId));

    [HttpPatch("cobrosdigitales/{pagoId:int}/pendiente")]
    [Permiso("finanzas.cierres", Accion.Confirmar)]
    public async Task<IActionResult> QuitarVerificacion(int pagoId) =>
        Ok(await _cobros.QuitarVerificacionAsync(pagoId));

    [HttpPatch("cobrosdigitales/{pagoId:int}/rechazar")]
    [Permiso("finanzas.cierres", Accion.Confirmar)]
    public async Task<IActionResult> Rechazar(int pagoId, [FromBody] RechazarCobroRequest request) =>
        Ok(await _cobros.RechazarAsync(pagoId, request, UsuarioId));
}
