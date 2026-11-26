using Backend.Dtos.Requests;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IUsuarioService _usuarioService;

    public AuthController(IUsuarioService usuarioService)
    {
        _usuarioService = usuarioService;
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var response = await _usuarioService.LoginAsync(request);
        return Ok(response);
    }

    // Aquí había un POST "register" anónimo que creaba usuarios del sistema con el rol que se pidiera (incluso
    // administrador) sin sesión. Ninguna pantalla lo usaba: los usuarios se crean desde Configuración
    // (UsuarioController, con permiso config.usuarios:crear). Se quitó: no debe volver.
}
