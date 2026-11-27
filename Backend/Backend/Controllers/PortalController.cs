using Backend.Dtos.Requests;
using Backend.Service.Implementacion;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// El portal de clientes (/portal). Sin sesión: abrir el enlace de invitación o de recuperación, activarlo, entrar y
/// pedir otra contraseña. Con la sesión del portal (otro esquema: el token del panel no sirve aquí y el de aquí no
/// sirve en el resto del API): el catálogo con sus precios y sus cotizaciones.
/// </summary>
[ApiController]
[Route("api/portal")]
[Authorize(AuthenticationSchemes = PortalJwt.Esquema)]
public class PortalController : ControllerBase
{
    private readonly IPortalAccesoService _accesos;
    private readonly ICotizacionService _cotizaciones;

    public PortalController(IPortalAccesoService accesos, ICotizacionService cotizaciones)
    {
        _accesos = accesos;
        _cotizaciones = cotizaciones;
    }

    // ------------------------------------------------------------ Sin sesión

    [HttpGet("enlace/{token}")]
    [AllowAnonymous]
    public async Task<IActionResult> VerEnlace(string token) => Ok(await _accesos.VerEnlaceAsync(token));

    [HttpPost("activar")]
    [AllowAnonymous]
    public async Task<IActionResult> Activar([FromBody] PortalActivarRequest request) => Ok(await _accesos.ActivarAsync(request));

    [HttpPost("restablecer")]
    [AllowAnonymous]
    public async Task<IActionResult> Restablecer([FromBody] PortalRestablecerRequest request) =>
        Ok(await _accesos.RestablecerAsync(request));

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login([FromBody] PortalLoginRequest request) => Ok(await _accesos.LoginAsync(request));

    [HttpPost("olvide")]
    [AllowAnonymous]
    public async Task<IActionResult> Olvide([FromBody] PortalOlvideRequest request)
    {
        await _accesos.OlvideAsync(request);
        // Siempre lo mismo, exista o no la cuenta: no sirve para averiguar quién es cliente.
        return Ok(new { message = "Si tu cuenta existe, te llegará un WhatsApp con el enlace para crear una contraseña nueva." });
    }

    // ------------------------------------------------------- Con sesión

    [HttpGet("yo")]
    public async Task<IActionResult> Yo() => Ok(await _accesos.YoAsync());

    /// <summary>Mi perfil: otro usuario (con la contraseña actual).</summary>
    [HttpPut("perfil/usuario")]
    public async Task<IActionResult> CambiarUsuario([FromBody] PortalCambiarUsuarioRequest request) =>
        Ok(await _accesos.CambiarUsuarioAsync(request));

    /// <summary>Mi perfil: otra contraseña (con la actual). Devuelve la sesión nueva de este celular.</summary>
    [HttpPut("perfil/password")]
    public async Task<IActionResult> CambiarPassword([FromBody] PortalCambiarPasswordRequest request) =>
        Ok(await _accesos.CambiarPasswordAsync(request));

    [HttpGet("catalogo")]
    public async Task<IActionResult> Catalogo() => Ok(await _cotizaciones.CatalogoAsync());

    [HttpGet("cotizaciones")]
    public async Task<IActionResult> MisCotizaciones() => Ok(await _cotizaciones.MisCotizacionesAsync());

    /// <summary>Los productos marcados con el corazón (ids).</summary>
    [HttpGet("favoritos")]
    public async Task<IActionResult> Favoritos() => Ok(await _cotizaciones.FavoritosAsync());

    [HttpPut("favoritos/{productoId:int}")]
    public async Task<IActionResult> MarcarFavorito(int productoId) =>
        Ok(await _cotizaciones.MarcarFavoritoAsync(productoId, true));

    [HttpDelete("favoritos/{productoId:int}")]
    public async Task<IActionResult> QuitarFavorito(int productoId) =>
        Ok(await _cotizaciones.MarcarFavoritoAsync(productoId, false));

    [HttpPost("cotizaciones")]
    public async Task<IActionResult> Crear([FromBody] CrearCotizacionRequest request) =>
        Ok(await _cotizaciones.CrearAsync(request));

    [HttpPatch("cotizaciones/{id:int}/cancelar")]
    public async Task<IActionResult> Cancelar(int id) => Ok(await _cotizaciones.CancelarAsync(id));
}
