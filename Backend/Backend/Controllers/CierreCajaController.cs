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
    private readonly IPermisoService _permisos;

    public CierreCajaController(ICierreCajaService cierres, ICobroDigitalService cobros, IPermisoService permisos)
    {
        _cierres = cierres;
        _cobros = cobros;
        _permisos = permisos;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    /// <summary>
    /// De quién son los cierres y cobros que puede ver y tocar: null si los de todos; su propio id
    /// si su alcance (Accesos → Alcance) lo limita a lo suyo.
    /// </summary>
    private async Task<int?> SoloDeAsync() =>
        UsuarioId is int uid && await _permisos.AlcanceAsync(uid, "finanzas.cierres") != AlcanceDatos.Todos
            ? uid
            : null;

    [HttpGet]
    [Permiso("finanzas.cierres", Accion.Ver)]
    public async Task<IActionResult> Listar([FromQuery] DateTime desde, [FromQuery] DateTime hasta) =>
        Ok(await _cierres.ListarAsync(desde, hasta, await SoloDeAsync()));

    /// <summary>Todo lo del cierre para revisar si cuadra: efectivo, digital y billetes.</summary>
    [HttpGet("{id:int}/detalle")]
    [Permiso("finanzas.cierres", Accion.Ver)]
    public async Task<IActionResult> Detalle(int id) => Ok(await _cierres.DetalleAsync(id, await SoloDeAsync()));

    [HttpPatch("{id:int}/anular")]
    [Permiso("finanzas.cierres", Accion.Anular)]
    public async Task<IActionResult> Anular(int id) =>
        Ok(await _cierres.AnularAsync(id, UsuarioId, await SoloDeAsync()));

    /*
     * Los cobros por Yape, Plin o transferencia no se cuentan en el cierre —esa
     * plata no pasa por la caja—, así que se cuadran aquí: se buscan en el
     * banco por su número de operación.
     */

    [HttpGet("cobrosdigitales")]
    [Permiso("finanzas.cierres", Accion.Ver)]
    public async Task<IActionResult> CobrosDigitales([FromQuery] DateTime desde, [FromQuery] DateTime hasta) =>
        Ok(await _cobros.ListarAsync(desde, hasta, await SoloDeAsync()));

    [HttpPatch("cobrosdigitales/{pagoId:int}/verificar")]
    [Permiso("finanzas.cierres", Accion.Confirmar)]
    public async Task<IActionResult> Verificar(int pagoId) =>
        Ok(await _cobros.VerificarAsync(pagoId, UsuarioId, await SoloDeAsync()));

    [HttpPatch("cobrosdigitales/{pagoId:int}/pendiente")]
    [Permiso("finanzas.cierres", Accion.Confirmar)]
    public async Task<IActionResult> QuitarVerificacion(int pagoId) =>
        Ok(await _cobros.QuitarVerificacionAsync(pagoId, await SoloDeAsync()));

    [HttpPatch("cobrosdigitales/{pagoId:int}/rechazar")]
    [Permiso("finanzas.cierres", Accion.Confirmar)]
    public async Task<IActionResult> Rechazar(int pagoId, [FromBody] RechazarCobroRequest request) =>
        Ok(await _cobros.RechazarAsync(pagoId, request, UsuarioId, await SoloDeAsync()));
}
