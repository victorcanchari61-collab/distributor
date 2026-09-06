using System.Security.Claims;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.Infrastructure;

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
public class PermisoAttribute : Attribute, IAsyncAuthorizationFilter, IAsyncActionFilter
{
    public string Submodulo { get; }
    public string Accion { get; }

    /// <summary>Donde queda anotado el permiso de un solo uso hasta gastarlo.</summary>
    private const string PendienteKey = "permiso.unico.pendiente";

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
        var veredicto = await permisos.ResolverAsync(usuarioId, Submodulo, Accion);

        if (veredicto.Permitido)
        {
            // Todavia no se gasta: solo se anota cual habria que gastar.
            if (veredicto.PermisoUnicoId is int id)
                context.HttpContext.Items[PendienteKey] = id;
            return;
        }

        // El 403 lleva qué se pidió, no solo que se negó: con eso el front
        // abre el modal para solicitarle ese permiso exacto a un admin, en vez
        // de mostrar un "no autorizado" del que nadie puede hacer nada.
        context.Result = new ObjectResult(new
        {
            // "message" y no "error": es el nombre que ya usa el middleware de
            // excepciones, y asi el cliente lee todos los errores igual.
            statusCode = StatusCodes.Status403Forbidden,
            message = "No tienes permiso para esta acción.",
            submodulo = Submodulo,
            accion = Accion,
        })
        {
            StatusCode = StatusCodes.Status403Forbidden,
        };
    }

    /// <summary>
    /// Gasta el permiso de un solo uso, y solo si la operación salió bien.
    ///
    /// Autorizar y consumir son dos momentos distintos a proposito: quien pidio
    /// "anular esta nota" y se topa con un error de validacion no puede quedarse
    /// sin el permiso por algo que nunca llego a hacer.
    /// </summary>
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var ejecutado = await next();

        if (context.HttpContext.Items[PendienteKey] is not int permisoId) return;

        // Una excepcion sin manejar deja Exception puesta y el middleware la
        // convertira en un 500: tampoco cuenta como usado.
        if (ejecutado.Exception is not null) return;

        var codigo = (ejecutado.Result as IStatusCodeActionResult)?.StatusCode
                     ?? context.HttpContext.Response.StatusCode;
        if (codigo >= 400) return;

        var permisos = context.HttpContext.RequestServices.GetRequiredService<IPermisoService>();
        await permisos.ConsumirAsync(permisoId);
    }
}
