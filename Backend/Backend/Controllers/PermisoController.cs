using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Filters;
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

    /// <summary>Las excepciones de una persona, vigentes y pasadas.</summary>
    [HttpGet("usuario/{usuarioId:int}")]
    [Permiso("config.accesos", Accion.Ver)]
    public async Task<IActionResult> DeUsuario(int usuarioId) =>
        Ok((await _permisos.ExcepcionesAsync(usuarioId)).Select(Mapear));

    /// <summary>
    /// Concede a una persona algo que su rol no le da.
    ///
    /// Se exige "editar accesos" y no un permiso propio a proposito: conceder
    /// permisos ES configurar accesos, y separarlo dejaria la puerta de que
    /// alguien se autoconcediera lo que quisiera.
    /// </summary>
    [HttpPost("conceder")]
    [Permiso("config.accesos", Accion.Editar)]
    public async Task<IActionResult> Conceder([FromBody] ConcederPermisoRequest request)
    {
        var texto = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        int.TryParse(texto, out var otorgante);

        var creado = await _permisos.ConcederAsync(new UsuarioPermiso
        {
            UsuarioId = request.UsuarioId,
            Submodulo = request.Submodulo,
            Accion = request.Accion,
            Alcance = request.Alcance,
            ExpiraEn = request.ExpiraEn,
            Motivo = request.Motivo,
            OtorgadoPorId = otorgante == 0 ? null : otorgante,
        });

        return Ok(Mapear(creado));
    }

    /// <summary>Retira una excepción antes de que venza o se gaste.</summary>
    [HttpPatch("{id:int}/revocar")]
    [Permiso("config.accesos", Accion.Editar)]
    public async Task<IActionResult> Revocar(int id)
    {
        await _permisos.RevocarAsync(id);
        return NoContent();
    }

    /// <summary>
    /// Pide una acción con la que uno se topó bloqueado.
    ///
    /// No lleva atributo de permiso a proposito: pedir tiene que poder hacerlo
    /// cualquiera que haya iniciado sesion. Exigir un permiso para pedir
    /// permisos dejaria fuera justo a quien lo necesita.
    /// </summary>
    [HttpPost("solicitar")]
    public async Task<IActionResult> Solicitar([FromBody] SolicitarPermisoRequest request)
    {
        if (UsuarioActual() is not int usuarioId) return Unauthorized();

        var solicitud = await _permisos.SolicitarAsync(new SolicitudPermiso
        {
            UsuarioId = usuarioId,
            Submodulo = request.Submodulo,
            Accion = request.Accion,
            Motivo = request.Motivo,
            Referencia = request.Referencia,
        });

        return Ok(Mapear(solicitud));
    }

    /// <summary>Lo que uno mismo pidió y en qué quedó.</summary>
    [HttpGet("solicitudes/mias")]
    public async Task<IActionResult> MisSolicitudes()
    {
        if (UsuarioActual() is not int usuarioId) return Unauthorized();
        return Ok((await _permisos.MisSolicitudesAsync(usuarioId)).Select(Mapear));
    }

    /// <summary>La bandeja del admin.</summary>
    [HttpGet("solicitudes")]
    [Permiso("config.accesos", Accion.Ver)]
    public async Task<IActionResult> Solicitudes([FromQuery] bool soloPendientes = false) =>
        Ok((await _permisos.SolicitudesAsync(soloPendientes)).Select(Mapear));

    [HttpPost("solicitudes/{id:int}/aprobar")]
    [Permiso("config.accesos", Accion.Editar)]
    public async Task<IActionResult> Aprobar(int id, [FromBody] AprobarSolicitudRequest request)
    {
        if (UsuarioActual() is not int adminId) return Unauthorized();

        var solicitud = await _permisos.AprobarAsync(
            id, adminId, request.Alcance, request.ExpiraEn, request.Respuesta);

        return Ok(Mapear(solicitud));
    }

    [HttpPost("solicitudes/{id:int}/rechazar")]
    [Permiso("config.accesos", Accion.Editar)]
    public async Task<IActionResult> Rechazar(int id, [FromBody] RechazarSolicitudRequest request)
    {
        if (UsuarioActual() is not int adminId) return Unauthorized();
        return Ok(Mapear(await _permisos.RechazarAsync(id, adminId, request.Respuesta)));
    }

    private int? UsuarioActual() =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"),
            out var id)
            ? id
            : null;

    private static SolicitudPermisoResponse Mapear(SolicitudPermiso s) => new()
    {
        Id = s.Id,
        UsuarioId = s.UsuarioId,
        Usuario = s.Usuario?.Nombre ?? string.Empty,
        Submodulo = s.Submodulo,
        Accion = s.Accion,
        Motivo = s.Motivo,
        Referencia = s.Referencia,
        Estado = s.Estado,
        FechaSolicitud = s.FechaSolicitud,
        FechaResolucion = s.FechaResolucion,
        Respuesta = s.Respuesta,
    };

    private static UsuarioPermisoResponse Mapear(UsuarioPermiso p) => new()
    {
        Id = p.Id,
        UsuarioId = p.UsuarioId,
        Submodulo = p.Submodulo,
        Accion = p.Accion,
        Alcance = p.Alcance,
        ExpiraEn = p.ExpiraEn,
        Usos = p.Usos,
        Revocado = p.Revocado,
        Motivo = p.Motivo,
        FechaOtorgado = p.FechaOtorgado,
        Vigente = p.Vigente(DateTime.UtcNow),
    };
}
