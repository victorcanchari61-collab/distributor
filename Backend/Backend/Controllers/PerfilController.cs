using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Exceptions;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// El perfil de quien tiene la sesion abierta.
///
/// Va aparte de UsuarioController a proposito: alli todo cuelga del permiso
/// "config.usuarios", que un vendedor o un almacenero no tienen. Aqui cada uno
/// edita lo suyo —nombre, correo, telefono, foto— y su contrasena, sin poder
/// tocarse el rol ni el estado.
/// </summary>
[ApiController]
[Route("api/perfil")]
[Authorize]
public class PerfilController : ControllerBase
{
    private readonly IUsuarioService _usuarioService;

    public PerfilController(IUsuarioService usuarioService)
    {
        _usuarioService = usuarioService;
    }

    [HttpGet]
    public async Task<IActionResult> Get()
    {
        return Ok(await _usuarioService.GetPerfilAsync(UsuarioId()));
    }

    [HttpPut]
    public async Task<IActionResult> Update([FromBody] ActualizarPerfilRequest request)
    {
        return Ok(await _usuarioService.UpdatePerfilAsync(UsuarioId(), request));
    }

    [HttpPut("password")]
    public async Task<IActionResult> CambiarPassword([FromBody] CambiarPasswordRequest request)
    {
        await _usuarioService.CambiarPasswordAsync(UsuarioId(), request);
        return NoContent();
    }

    /// <summary>El id sale del token, nunca del cuerpo ni de la URL.</summary>
    private int UsuarioId()
    {
        var texto = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        return int.TryParse(texto, out var id)
            ? id
            : throw new UnauthorizedException("Sesión inválida");
    }
}
