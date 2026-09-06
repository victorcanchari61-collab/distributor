using System.Security.Claims;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Lo que el front necesita saber sobre permisos: qué existe y qué tengo.
/// </summary>
[ApiController]
[Route("api/permiso")]
[Authorize]
public class PermisoController : ControllerBase
{
    private readonly IPermisoService _permisos;

    public PermisoController(IPermisoService permisos)
    {
        _permisos = permisos;
    }

    /// <summary>
    /// Qué submódulos hay y qué acciones admite cada uno.
    ///
    /// La pantalla de Accesos dibuja su matriz con esto en vez de con una
    /// lista propia: si la copiara, un submódulo nuevo quedaria invisible en
    /// la configuración aunque el backend ya lo estuviera exigiendo.
    /// </summary>
    [HttpGet("catalogo")]
    public IActionResult Catalogo() =>
        Ok(CatalogoPermisos.Submodulos.Select(par => new
        {
            submodulo = par.Key,
            modulo = CatalogoPermisos.ModuloDe(par.Key),
            acciones = par.Value,
        }));

    /// <summary>
    /// Los permisos de quien pregunta, como "submodulo:accion".
    ///
    /// Con esto el menú esconde lo que no se puede abrir y los botones de
    /// anular o exportar no se pintan. Es comodidad, no seguridad: quien
    /// llame igual al endpoint se topa con el filtro del servidor.
    /// </summary>
    [HttpGet("mios")]
    public async Task<IActionResult> Mios()
    {
        var texto = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (!int.TryParse(texto, out var usuarioId)) return Unauthorized();

        return Ok(await _permisos.DeUsuarioAsync(usuarioId));
    }
}
