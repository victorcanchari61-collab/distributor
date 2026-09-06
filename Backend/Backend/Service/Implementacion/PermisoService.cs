using Backend.Data;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace Backend.Service.Implementacion;

/// <summary>
/// Los permisos salen del rol del usuario más sus excepciones, resueltos
/// contra la base.
///
/// Podrian viajar en el token — seria una consulta menos — pero entonces
/// quitarle un permiso a alguien no surtiria efecto hasta que su sesion
/// venciera, y darselo lo obligaria a volver a entrar. En un sistema donde el
/// admin concede permisos en el momento, eso no sirve. Se cachea lo del rol,
/// que es lo que de verdad se repite: cincuenta vendedores comparten una sola
/// fila de permisos. Las excepciones NO se cachean — son pocas por persona, y
/// una de un solo uso cacheada seguiria pareciendo valida despues de gastarse.
/// </summary>
public class PermisoService : IPermisoService
{
    private readonly AppDbContext _context;
    private readonly IMemoryCache _cache;
    private readonly INotificador _notificador;

    /// <summary>
    /// Corto a proposito. La caché es para no repetir la misma consulta en
    /// rafagas de requests, no para vivir de ella: si algo se escapa a
    /// <see cref="OlvidarRol"/>, se corrige solo en menos de un minuto.
    /// </summary>
    private static readonly TimeSpan Vigencia = TimeSpan.FromSeconds(30);

    public PermisoService(AppDbContext context, IMemoryCache cache, INotificador notificador)
    {
        _context = context;
        _cache = cache;
        _notificador = notificador;
    }

    private static string Llave(int rolId) => $"permisos:rol:{rolId}";

    /// <summary>Todo el catálogo, para el rol que no se restringe.</summary>
    private static readonly IReadOnlySet<string> Todos = CatalogoPermisos.Submodulos
        .SelectMany(par => par.Value.Select(a => $"{par.Key}:{a}"))
        .ToHashSet();

    public async Task<IReadOnlySet<string>> DeUsuarioAsync(int usuarioId)
    {
        var usuario = await UsuarioAsync(usuarioId);
        if (usuario is null) return new HashSet<string>();
        if (usuario.EsAdministrador) return Todos;

        var permisos = new HashSet<string>(await DeRolAsync(usuario.RolId));
        foreach (var e in await VigentesAsync(usuarioId))
        {
            permisos.Add($"{e.Submodulo}:{e.Accion}");
        }
        return permisos;
    }

    public async Task<Veredicto> ResolverAsync(int usuarioId, string submodulo, string accion)
    {
        var usuario = await UsuarioAsync(usuarioId);
        if (usuario is null) return Veredicto.No;
        if (usuario.EsAdministrador) return Veredicto.PorRol;

        // El rol primero: si ya lo cubre, no se toca ninguna excepcion — asi un
        // permiso de un solo uso no se gasta por algo que la persona podia
        // hacer igual.
        if ((await DeRolAsync(usuario.RolId)).Contains($"{submodulo}:{accion}"))
            return Veredicto.PorRol;

        var excepciones = (await VigentesAsync(usuarioId))
            .Where(e => e.Submodulo == submodulo && e.Accion == accion)
            .ToList();

        if (excepciones.Count == 0) return Veredicto.No;

        // Entre varias vale la que no se gasta: quemar el permiso de un solo
        // uso teniendo uno permanente seria tirar el que hace falta guardar.
        var duradera = excepciones.FirstOrDefault(e => e.Alcance != AlcancePermiso.UnaVez);
        if (duradera is not null) return Veredicto.PorRol;

        return new Veredicto(true, excepciones[0].Id);
    }

    public async Task<bool> PuedeAsync(int usuarioId, string submodulo, string accion) =>
        (await ResolverAsync(usuarioId, submodulo, accion)).Permitido;

    public async Task ConsumirAsync(int permisoId)
    {
        // El WHERE lleva la condicion, no solo el Id: dos requests en paralelo
        // con el mismo permiso pendiente entrarian los dos, y sin esto ambos lo
        // darian por bueno. Asi el segundo actualiza cero filas.
        await _context.UsuarioPermisos
            .Where(p => p.Id == permisoId && p.Usos == 0 && !p.Revocado)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.Usos, 1));
    }

    public void OlvidarRol(int rolId) => _cache.Remove(Llave(rolId));

    public async Task<IReadOnlyList<UsuarioPermiso>> ExcepcionesAsync(int usuarioId) =>
        await _context.UsuarioPermisos
            .AsNoTracking()
            .Where(p => p.UsuarioId == usuarioId)
            .OrderByDescending(p => p.FechaOtorgado)
            .ThenByDescending(p => p.Id)
            .ToListAsync();

    public async Task<UsuarioPermiso> ConcederAsync(UsuarioPermiso permiso)
    {
        if (!CatalogoPermisos.EsValido(permiso.Submodulo, permiso.Accion))
        {
            throw new BadRequestException(
                $"'{permiso.Accion}' no es una acción de {permiso.Submodulo}");
        }

        if (permiso.Alcance == AlcancePermiso.Temporal && permiso.ExpiraEn is null)
        {
            throw new BadRequestException("Un permiso temporal necesita fecha de vencimiento");
        }

        // Fuera de Temporal la fecha no significa nada, y guardada confundiria a
        // quien luego revise por que caduco algo que no caduca.
        if (permiso.Alcance != AlcancePermiso.Temporal) permiso.ExpiraEn = null;

        permiso.FechaOtorgado = DateTime.UtcNow;
        permiso.Usos = 0;
        permiso.Revocado = false;

        _context.UsuarioPermisos.Add(permiso);
        await _context.SaveChangesAsync();
        return permiso;
    }

    public async Task RevocarAsync(int permisoId)
    {
        var filas = await _context.UsuarioPermisos
            .Where(p => p.Id == permisoId)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.Revocado, true));

        if (filas == 0) throw new NotFoundException("Permiso no encontrado");
    }

    public async Task<SolicitudPermiso> SolicitarAsync(SolicitudPermiso solicitud)
    {
        if (!CatalogoPermisos.EsValido(solicitud.Submodulo, solicitud.Accion))
        {
            throw new BadRequestException(
                $"'{solicitud.Accion}' no es una acción de {solicitud.Submodulo}");
        }

        // Pulsar dos veces el boton no debe llenarle la bandeja al admin de
        // copias de lo mismo; se le devuelve la que ya tiene abierta.
        var abierta = await _context.SolicitudesPermiso
            .FirstOrDefaultAsync(s => s.UsuarioId == solicitud.UsuarioId
                                      && s.Submodulo == solicitud.Submodulo
                                      && s.Accion == solicitud.Accion
                                      && s.Estado == EstadoSolicitud.Pendiente);
        if (abierta is not null) return abierta;

        solicitud.Estado = EstadoSolicitud.Pendiente;
        solicitud.FechaSolicitud = DateTime.UtcNow;

        _context.SolicitudesPermiso.Add(solicitud);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("permisos", "solicitada", new { solicitud.Id });
        return solicitud;
    }

    public async Task<IReadOnlyList<SolicitudPermiso>> SolicitudesAsync(bool soloPendientes)
    {
        var consulta = _context.SolicitudesPermiso.AsNoTracking().Include(s => s.Usuario).AsQueryable();
        if (soloPendientes) consulta = consulta.Where(s => s.Estado == EstadoSolicitud.Pendiente);

        // Lo pendiente arriba aunque sea lo mas viejo: es lo unico sobre lo que
        // hay algo que hacer.
        return await consulta
            .OrderBy(s => s.Estado == EstadoSolicitud.Pendiente ? 0 : 1)
            .ThenByDescending(s => s.FechaSolicitud)
            .Take(200)
            .ToListAsync();
    }

    public async Task<IReadOnlyList<SolicitudPermiso>> MisSolicitudesAsync(int usuarioId) =>
        await _context.SolicitudesPermiso
            .AsNoTracking()
            .Where(s => s.UsuarioId == usuarioId)
            .OrderByDescending(s => s.FechaSolicitud)
            .Take(50)
            .ToListAsync();

    public async Task<SolicitudPermiso> AprobarAsync(
        int solicitudId, int adminId, AlcancePermiso alcance, DateTime? expiraEn, string? respuesta)
    {
        var solicitud = await PendienteAsync(solicitudId);

        var permiso = await ConcederAsync(new UsuarioPermiso
        {
            UsuarioId = solicitud.UsuarioId,
            Submodulo = solicitud.Submodulo,
            Accion = solicitud.Accion,
            Alcance = alcance,
            ExpiraEn = expiraEn,
            // El motivo lo escribio quien pidio; se arrastra para que el
            // permiso concedido diga para que era sin abrir la solicitud.
            Motivo = solicitud.Motivo,
            OtorgadoPorId = adminId,
        });

        solicitud.Estado = EstadoSolicitud.Aprobada;
        solicitud.ResueltaPorId = adminId;
        solicitud.FechaResolucion = DateTime.UtcNow;
        solicitud.Respuesta = respuesta;
        solicitud.PermisoId = permiso.Id;

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("permisos", "aprobada", new { solicitud.Id, solicitud.UsuarioId });
        return solicitud;
    }

    public async Task<SolicitudPermiso> RechazarAsync(int solicitudId, int adminId, string? respuesta)
    {
        var solicitud = await PendienteAsync(solicitudId);

        solicitud.Estado = EstadoSolicitud.Rechazada;
        solicitud.ResueltaPorId = adminId;
        solicitud.FechaResolucion = DateTime.UtcNow;
        solicitud.Respuesta = respuesta;

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("permisos", "rechazada", new { solicitud.Id, solicitud.UsuarioId });
        return solicitud;
    }

    private async Task<SolicitudPermiso> PendienteAsync(int id)
    {
        var solicitud = await _context.SolicitudesPermiso.FirstOrDefaultAsync(s => s.Id == id)
            ?? throw new NotFoundException("Solicitud no encontrada");

        // Dos admins pueden tener la bandeja abierta a la vez: sin esto el
        // segundo concederia un permiso duplicado sobre algo ya resuelto.
        if (solicitud.Estado != EstadoSolicitud.Pendiente)
            throw new ConflictException("Esa solicitud ya fue resuelta");

        return solicitud;
    }

    private record UsuarioMinimo(int RolId, bool EsAdministrador);

    private async Task<UsuarioMinimo?> UsuarioAsync(int usuarioId) =>
        await _context.Usuarios
            .AsNoTracking()
            .Where(u => u.Id == usuarioId && u.Activo)
            // El administrador no se configura: si su matriz quedara a medias se
            // quedaria fuera de la propia pantalla que arregla los permisos.
            .Select(u => new UsuarioMinimo(u.RolId, u.Rol!.Nombre == "Administrador"))
            .FirstOrDefaultAsync();

    private async Task<IReadOnlySet<string>> DeRolAsync(int rolId)
    {
        if (_cache.TryGetValue(Llave(rolId), out IReadOnlySet<string>? guardado) && guardado is not null)
            return guardado;

        var permisos = await _context.RolPermisos
            .AsNoTracking()
            .Where(p => p.RolId == rolId)
            .Select(p => p.Submodulo + ":" + p.Accion)
            .ToListAsync();

        IReadOnlySet<string> resultado = permisos.ToHashSet();
        _cache.Set(Llave(rolId), resultado, Vigencia);
        return resultado;
    }

    private async Task<List<UsuarioPermiso>> VigentesAsync(int usuarioId)
    {
        var ahora = DateTime.UtcNow;

        // El grueso se descarta en SQL; lo que queda son pocas filas y el
        // detalle de que cuenta como vigente vive en el modelo, en un solo sitio.
        var candidatas = await _context.UsuarioPermisos
            .AsNoTracking()
            .Where(p => p.UsuarioId == usuarioId
                        && !p.Revocado
                        && (p.ExpiraEn == null || p.ExpiraEn > ahora)
                        && (p.Alcance != AlcancePermiso.UnaVez || p.Usos == 0))
            .OrderBy(p => p.Id)
            .ToListAsync();

        return candidatas.Where(p => p.Vigente(ahora)).ToList();
    }
}
