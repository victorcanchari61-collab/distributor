using System.Security.Claims;
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

    public CierreCajaController(ICierreCajaService cierres)
    {
        _cierres = cierres;
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
}
