using System.Security.Claims;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Backend.Filters;

/// <summary>
/// Deja entrar a quien tenga CUALQUIERA de los permisos listados.
///
/// Existe para las consultas que varias pantallas necesitan de otro módulo.
/// Quien toma un pedido tiene que ver cuánto stock queda para prometer y de qué
/// almacén sale, pero eso vivía detrás de <c>inv.stock</c> e
/// <c>inv.almacenes</c>: un vendedor sin acceso a Inventario recibía un 403
/// que la pantalla no mostraba, y todos los productos aparecían con stock 0.
/// Darle Inventario entero para arreglarlo le abría los costos y los ajustes.
///
/// Se usa solo en lecturas que no gastan nada: a diferencia de
/// <see cref="PermisoAttribute"/>, no consume permisos de un solo uso — mirar
/// cuánto hay no debe quemar el permiso que alguien pidió para anular algo.
///
/// Uso: <c>[PermisoAlguno("inv.stock:ver", "fact.pedidos:ver")]</c>.
/// </summary>
[AttributeUsage(AttributeTargets.Method)]
public class PermisoAlgunoAttribute : Attribute, IAsyncAuthorizationFilter
{
    /// <summary>Claves "submodulo:accion".</summary>
    public string[] Claves { get; }

    public PermisoAlgunoAttribute(params string[] claves)
    {
        Claves = claves;
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

        foreach (var clave in Claves)
        {
            var (submodulo, accion) = Partir(clave);
            if (await permisos.PuedeAsync(usuarioId, submodulo, accion)) return;
        }

        // Se pide el primero de la lista, que es el natural para esa consulta:
        // con eso el front ofrece solicitar algo concreto y no un rechazo mudo.
        var (primerSubmodulo, primeraAccion) = Partir(Claves[0]);
        context.Result = new ObjectResult(new
        {
            statusCode = StatusCodes.Status403Forbidden,
            message = "No tienes permiso para esta acción.",
            submodulo = primerSubmodulo,
            accion = primeraAccion,
        })
        {
            StatusCode = StatusCodes.Status403Forbidden,
        };
    }

    private static (string Submodulo, string Accion) Partir(string clave)
    {
        var i = clave.LastIndexOf(':');
        return (clave[..i], clave[(i + 1)..]);
    }
}
