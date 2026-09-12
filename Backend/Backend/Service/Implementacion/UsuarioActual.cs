using System.Security.Claims;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

/// <summary>
/// Quién está pidiendo, leído del token de la petición en curso.
///
/// Existe para que los servicios puedan acotar lo que devuelven sin que el id
/// del usuario tenga que viajar como parámetro por toda la cadena. Pasarlo a
/// mano por cada método tenía un problema peor que la incomodidad: el día que
/// alguien añade una consulta nueva y se olvida del parámetro, esa consulta
/// devuelve TODO y nadie lo nota, porque funciona.
/// </summary>
public class UsuarioActual : IUsuarioActual
{
    private readonly IHttpContextAccessor _contexto;

    public UsuarioActual(IHttpContextAccessor contexto)
    {
        _contexto = contexto;
    }

    public int? Id
    {
        get
        {
            var usuario = _contexto.HttpContext?.User;
            if (usuario is null) return null;

            var texto = usuario.FindFirstValue(ClaimTypes.NameIdentifier)
                        ?? usuario.FindFirstValue("sub");

            return int.TryParse(texto, out var id) ? id : null;
        }
    }
}
