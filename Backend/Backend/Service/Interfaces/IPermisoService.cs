using Backend.Models;

namespace Backend.Service.Interfaces;

/// <summary>
/// De dónde salió un permiso concedido.
/// </summary>
/// <param name="Permitido">Si la acción se puede hacer.</param>
/// <param name="PermisoUnicoId">
/// La excepción de un solo uso que lo autoriza, si fue eso lo que lo permitió.
/// Todavia sin gastar: se marca despues, solo si la operacion sale bien.
/// </param>
public readonly record struct Veredicto(bool Permitido, int? PermisoUnicoId)
{
    public static readonly Veredicto No = new(false, null);
    public static readonly Veredicto PorRol = new(true, null);
}

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
    /// Todo lo que el usuario puede hacer, como claves "submodulo:accion":
    /// lo de su rol más las excepciones que tenga vigentes.
    ///
    /// Se resuelve contra la base y no contra el token: un permiso recién
    /// concedido tiene que servir sin que la persona cierre sesión.
    /// </summary>
    Task<IReadOnlySet<string>> DeUsuarioAsync(int usuarioId);

    /// <summary>
    /// Si ese usuario puede hacer esa acción, y con qué la puede.
    ///
    /// Devuelve el veredicto y no un bool porque un permiso de un solo uso hay
    /// que gastarlo despues, y para eso hace falta saber cual fue.
    /// </summary>
    Task<Veredicto> ResolverAsync(int usuarioId, string submodulo, string accion);

    /// <summary>Atajo para cuando no importa de dónde salga el permiso.</summary>
    Task<bool> PuedeAsync(int usuarioId, string submodulo, string accion);

    /// <summary>
    /// Gasta una excepción de un solo uso.
    ///
    /// Se llama cuando la operación ya salió bien: si se gastara al autorizar,
    /// un error de validación quemaria el permiso y la persona tendria que
    /// volver a pedirlo por algo que nunca llego a hacer.
    /// </summary>
    Task ConsumirAsync(int permisoId);

    /// <summary>
    /// Olvida lo que tenía guardado de un rol. Se llama al cambiar la matriz:
    /// sin esto, el cambio no se notaría hasta que venza la caché.
    /// </summary>
    void OlvidarRol(int rolId);

    /// <summary>Las excepciones de una persona, vigentes y pasadas.</summary>
    Task<IReadOnlyList<UsuarioPermiso>> ExcepcionesAsync(int usuarioId);

    /// <summary>Concede una excepción. Devuelve la fila creada.</summary>
    Task<UsuarioPermiso> ConcederAsync(UsuarioPermiso permiso);

    /// <summary>Retira una excepción antes de que venza o se gaste.</summary>
    Task RevocarAsync(int permisoId);

    /// <summary>
    /// Registra que alguien pidió una acción que no puede hacer.
    ///
    /// Si ya tiene una pendiente por lo mismo se devuelve esa: pulsar dos veces
    /// el boton no debe llenarle la bandeja al admin de copias.
    /// </summary>
    Task<SolicitudPermiso> SolicitarAsync(SolicitudPermiso solicitud);

    /// <summary>La bandeja: pendientes primero, luego lo ya resuelto.</summary>
    Task<IReadOnlyList<SolicitudPermiso>> SolicitudesAsync(bool soloPendientes);

    /// <summary>Las que pidió una persona, para que vea en qué quedaron.</summary>
    Task<IReadOnlyList<SolicitudPermiso>> MisSolicitudesAsync(int usuarioId);

    /// <summary>
    /// Aprueba una solicitud y concede el permiso con el alcance elegido.
    /// </summary>
    Task<SolicitudPermiso> AprobarAsync(
        int solicitudId, int adminId, AlcancePermiso alcance, DateTime? expiraEn, string? respuesta);

    /// <summary>Rechaza una solicitud. No concede nada.</summary>
    Task<SolicitudPermiso> RechazarAsync(int solicitudId, int adminId, string? respuesta);
}
