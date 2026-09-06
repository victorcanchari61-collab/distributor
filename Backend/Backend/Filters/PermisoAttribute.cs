using System.Security.Claims;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Backend.Filters;

/// <summary>
/// Exige un permiso concreto para entrar al endpoint.
///
/// Reemplaza al <c>[Authorize(Roles = "Administrador")]</c> escrito a mano que
/// habia repartido por los controladores: aquello ataba el permiso al nombre
/// de un rol, asi que crear un rol nuevo — "Supervisor", "Cajero" — no servia
/// de nada, y aflojar una sola accion obligaba a recompilar.
///
/// Uso: <c>[Permiso("fact.notaventa", Accion.Anular)]</c>.
/// </summary>
[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class)]
public class PermisoAttribute : Attribute, IAsyncAuthorizationFilter
{
    public string Submodulo { get; }
    public string Accion { get; }

    public PermisoAttribute(string submodulo, string accion)
    {
        Submodulo = submodulo;
        Accion = accion;
    }

    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        var usuario = context.HttpContext.User;
        if (usuario.Identity?.IsAuthenticated != true)
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        var texto = usuario.FindFirstValue(ClaimTypes.NameIdentifier) ?? usuario.FindFirstValue("sub");
        if (!int.TryParse(texto, out var usuarioId))
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        var permisos = context.HttpContext.RequestServices.GetRequiredService<IPermisoService>();
        if (await permisos.PuedeAsync(usuarioId, Submodulo, Accion)) return;

        // El 403 lleva qué se pidió, no solo que se negó: con eso el front
        // abre el modal para solicitarle ese permiso exacto a un admin, en vez
        // de mostrar un "no autorizado" del que nadie puede hacer nada.
        context.Result = new ObjectResult(new
        {
            error = "Sin permiso para esta acción.",
            submodulo = Submodulo,
            accion = Accion,
        })
        {
            StatusCode = StatusCodes.Status403Forbidden,
        };
    }
}
