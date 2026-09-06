using Backend.Data;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace Backend.Service.Implementacion;

/// <summary>
/// Los permisos salen del rol del usuario, resueltos contra la base.
///
/// Podrian viajar en el token — seria una consulta menos — pero entonces
/// quitarle un permiso a alguien no surtiria efecto hasta que su sesion
/// venciera, y darselo lo obligaria a volver a entrar. En un sistema donde el
/// admin concede permisos en el momento, eso no sirve. La consulta se cachea
/// por rol, que es lo que de verdad se repite: cincuenta vendedores comparten
/// una sola fila de permisos.
/// </summary>
public class PermisoService : IPermisoService
{
    private readonly AppDbContext _context;
    private readonly IMemoryCache _cache;

    /// <summary>
    /// Corto a proposito. La caché es para no repetir la misma consulta en
    /// rafagas de requests, no para vivir de ella: si algo se escapa a
    /// <see cref="OlvidarRol"/>, se corrige solo en menos de un minuto.
    /// </summary>
    private static readonly TimeSpan Vigencia = TimeSpan.FromSeconds(30);

    public PermisoService(AppDbContext context, IMemoryCache cache)
    {
        _context = context;
        _cache = cache;
    }

    private static string Llave(int rolId) => $"permisos:rol:{rolId}";

    public async Task<IReadOnlySet<string>> DeUsuarioAsync(int usuarioId)
    {
        var usuario = await _context.Usuarios
            .AsNoTracking()
            .Where(u => u.Id == usuarioId && u.Activo)
            .Select(u => new { u.RolId, RolNombre = u.Rol!.Nombre })
            .FirstOrDefaultAsync();

        if (usuario is null) return new HashSet<string>();

        // El administrador no se configura: si su matriz quedara a medias se
        // quedaria fuera de la propia pantalla que arregla los permisos.
        if (string.Equals(usuario.RolNombre, "Administrador", StringComparison.OrdinalIgnoreCase))
            return Todos;

        return await DeRolAsync(usuario.RolId);
    }

    /// <summary>Todo el catálogo, para el rol que no se restringe.</summary>
    private static readonly IReadOnlySet<string> Todos = CatalogoPermisos.Submodulos
        .SelectMany(par => par.Value.Select(a => $"{par.Key}:{a}"))
        .ToHashSet();

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

    public async Task<bool> PuedeAsync(int usuarioId, string submodulo, string accion) =>
        (await DeUsuarioAsync(usuarioId)).Contains($"{submodulo}:{accion}");

    public void OlvidarRol(int rolId) => _cache.Remove(Llave(rolId));
}
