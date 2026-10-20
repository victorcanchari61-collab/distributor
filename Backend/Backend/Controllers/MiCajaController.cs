using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// La Caja de quien está logueado: su propio dinero en la ruta. Cualquier
/// usuario ve la suya y la cierra sin necesitar un permiso de Finanzas — es
/// "lo mío", igual que Mi Perfil. Registrar un ingreso o un egreso sí pide su
/// permiso (`finanzas.caja`: ingreso / egreso), cada uno por separado. Un
/// supervisor ve la de otro desde `GET /cuentafinanciera`.
/// </summary>
[ApiController]
[Route("api/micaja")]
[Authorize]
public class MiCajaController : ControllerBase
{
    private readonly ICuentaFinancieraService _cuentas;
    private readonly IGastoOperativoService _gastos;
    private readonly ICierreCajaService _cierres;
    private readonly IPermisoService _permisos;

    public MiCajaController(
        ICuentaFinancieraService cuentas, IGastoOperativoService gastos, ICierreCajaService cierres, IPermisoService permisos)
    {
        _cuentas = cuentas;
        _gastos = gastos;
        _cierres = cierres;
        _permisos = permisos;
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

    /// <summary>
    /// Lo que cobró o pagó por Yape, Plin o transferencia: no pasa por su caja,
    /// pero es suyo y lo tiene que poder ver.
    /// </summary>
    [HttpGet("digitales")]
    public async Task<IActionResult> Digitales([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _cuentas.MovimientosDigitalesAsync(UsuarioId, desde, hasta));

    /// <summary>Un ingreso libre a la propia caja: no hace falta que sea una venta.</summary>
    [HttpPost("ingreso")]
    [Permiso("finanzas.caja", Accion.Ingreso)]
    public Task<IActionResult> RegistrarIngreso([FromBody] MovimientoOperativoRequest request) =>
        Registrar(request, TipoMovimientoOperativo.Ingreso);

    /// <summary>Un egreso libre de la propia caja: un pasaje, combustible, un gasto de ruta.</summary>
    [HttpPost("egreso")]
    [Permiso("finanzas.caja", Accion.Egreso)]
    public Task<IActionResult> RegistrarEgreso([FromBody] MovimientoOperativoRequest request) =>
        Registrar(request, TipoMovimientoOperativo.Egreso);

    /// <summary>
    /// La ruta de antes, para el APK que ya está instalado: pide el mismo permiso que las nuevas,
    /// según el tipo, y responde el mismo 403 (con qué se pidió, para solicitarlo).
    /// </summary>
    [HttpPost("movimiento")]
    public async Task<IActionResult> RegistrarMovimiento([FromBody] MovimientoOperativoRequest request)
    {
        var accion = request.Tipo == TipoMovimientoOperativo.Ingreso ? Accion.Ingreso : Accion.Egreso;
        if (!(await _permisos.ResolverAsync(UsuarioId, "finanzas.caja", accion)).Permitido)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                statusCode = StatusCodes.Status403Forbidden,
                message = "No tienes permiso para esta acción.",
                submodulo = "finanzas.caja",
                accion,
            });
        }

        return await Registrar(request, request.Tipo == TipoMovimientoOperativo.Ingreso
            ? TipoMovimientoOperativo.Ingreso
            : TipoMovimientoOperativo.Egreso);
    }

    private async Task<IActionResult> Registrar(MovimientoOperativoRequest request, string tipo)
    {
        var caja = await _cuentas.ExigirCajaUsuarioAsync(UsuarioId);
        // La cuenta y el tipo los decide el servidor: nunca los que vengan en el body — así nadie
        // postea a la caja de otro, ni registra un egreso por la ruta del ingreso.
        request.CuentaFinancieraId = caja.Id;
        request.Tipo = tipo;
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
