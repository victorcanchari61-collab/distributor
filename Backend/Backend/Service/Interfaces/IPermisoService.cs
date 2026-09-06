namespace Backend.Service.Interfaces;

/// <summary>
/// Resuelve qué puede hacer un usuario.
///
/// Hasta ahora los permisos eran decorativos: la matriz de Accesos se guardaba
/// pero nadie la leía, y lo que de verdad bloqueaba era el nombre del rol
/// escrito a mano en cada endpoint. Este servicio es el que la vuelve real.
/// </summary>
public interface IPermisoService
{
    /// <summary>
    /// Todo lo que el usuario puede hacer, como claves "submodulo:accion".
    ///
    /// Se resuelve contra la base y no contra el token: un permiso recién
    /// concedido tiene que servir sin que la persona cierre sesión.
    /// </summary>
    Task<IReadOnlySet<string>> DeUsuarioAsync(int usuarioId);

    /// <summary>Si ese usuario puede hacer esa acción en ese submódulo.</summary>
    Task<bool> PuedeAsync(int usuarioId, string submodulo, string accion);

    /// <summary>
    /// Olvida lo que tenía guardado de un rol. Se llama al cambiar la matriz:
    /// sin esto, el cambio no se notaría hasta que venza la caché.
    /// </summary>
    void OlvidarRol(int rolId);
}
