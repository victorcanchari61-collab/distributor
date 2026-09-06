using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Backend.Repository;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class AuditoriaRepository : IAuditoriaRepository
{
    private readonly AppDbContext _context;

    public AuditoriaRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<RegistroAuditoria>> GetAsync(
        string? entidad, string? accion, int? usuarioId, DateTime? desde, DateTime? hasta) =>
        await _context.RegistrosAuditoria
            .Include(r => r.Usuario)
            .Where(r => (entidad == null || r.Entidad == entidad)
                        && (accion == null || r.Accion == accion)
                        && (usuarioId == null || r.UsuarioId == usuarioId)
                        && (desde == null || r.Fecha >= desde)
                        && (hasta == null || r.Fecha <= hasta))
            .OrderByDescending(r => r.Fecha)
            .ThenByDescending(r => r.Id)
            .Take(300)
            .ToListAsync();

    public async Task<(List<RegistroAuditoria> Items, int Total)> ListarAsync(ConsultaTablaRequest consulta)
    {
        var query = _context.RegistrosAuditoria
            .Include(r => r.Usuario)
            .AsNoTracking()
            .AsQueryable();

        // Buscador general: las columnas de texto que alguien escribiria para
        // encontrar un cambio. Los valores viejo/nuevo quedan fuera a
        // proposito — son JSON y buscar dentro seria un escaneo completo.
        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(r =>
                EF.Functions.Like(r.Entidad, $"%{texto}%")
                || EF.Functions.Like(r.EntidadId, $"%{texto}%")
                || EF.Functions.Like(r.Accion, $"%{texto}%")
                || (r.Usuario != null && EF.Functions.Like(r.Usuario.Nombre, $"%{texto}%")));
        }

        if (consulta.ValorDe("entidad") is string entidad)
        {
            query = query.Where(r => r.Entidad == entidad);
        }

        if (consulta.ValorDe("accion") is string accion)
        {
            query = query.Where(r => r.Accion == accion);
        }

        if (consulta.ValorDe("entidadId") is string entidadId)
        {
            query = query.Where(r => EF.Functions.Like(r.EntidadId, $"%{entidadId}%"));
        }

        if (consulta.ValorDe("usuario") is string usuario)
        {
            query = query.Where(r => r.Usuario != null && r.Usuario.Nombre == usuario);
        }

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(r => r.Fecha >= desde);
        if (hasta is not null) query = query.Where(r => r.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        // El desempate por Id es lo que hace estable la paginacion: dos
        // cambios en el mismo instante podrian intercambiarse entre paginas.
        query = consulta.Orden switch
        {
            "usuario" => desc
                ? query.OrderByDescending(r => r.Usuario!.Nombre).ThenByDescending(r => r.Id)
                : query.OrderBy(r => r.Usuario!.Nombre).ThenBy(r => r.Id),
            "entidad" => desc
                ? query.OrderByDescending(r => r.Entidad).ThenByDescending(r => r.Id)
                : query.OrderBy(r => r.Entidad).ThenBy(r => r.Id),
            "entidadId" => desc
                ? query.OrderByDescending(r => r.EntidadId).ThenByDescending(r => r.Id)
                : query.OrderBy(r => r.EntidadId).ThenBy(r => r.Id),
            "accion" => desc
                ? query.OrderByDescending(r => r.Accion).ThenByDescending(r => r.Id)
                : query.OrderBy(r => r.Accion).ThenBy(r => r.Id),
            // Por defecto y por fecha: lo mas nuevo primero, que es como se lee
            // una bitacora.
            _ => desc
                ? query.OrderByDescending(r => r.Fecha).ThenByDescending(r => r.Id)
                : query.OrderBy(r => r.Fecha).ThenBy(r => r.Id),
        };

        return await query.PaginarAsync(consulta);
    }

    public async Task<ResumenAuditoriaResponse> ResumenAsync() => new()
    {
        Total = await _context.RegistrosAuditoria.CountAsync(),
        Creados = await _context.RegistrosAuditoria.CountAsync(r => r.Accion == AccionAuditoria.Creado),
        Actualizados = await _context.RegistrosAuditoria
            .CountAsync(r => r.Accion == AccionAuditoria.Actualizado),
        Eliminados = await _context.RegistrosAuditoria
            .CountAsync(r => r.Accion == AccionAuditoria.Eliminado),
        Entidades = await _context.RegistrosAuditoria
            .Select(r => r.Entidad).Distinct().OrderBy(e => e).ToListAsync(),
        Usuarios = await _context.RegistrosAuditoria
            .Where(r => r.Usuario != null)
            .Select(r => r.Usuario!.Nombre)
            .Distinct().OrderBy(u => u).ToListAsync(),
    };

    public async Task<IEnumerable<string>> GetEntidadesAsync() =>
        await _context.RegistrosAuditoria
            .Select(r => r.Entidad)
            .Distinct()
            .OrderBy(e => e)
            .ToListAsync();

    public async Task<IEnumerable<RegistroAuditoria>> GetHistorialDocumentoAsync(
        string entidadPrincipal, int id, string entidadDetalle, IEnumerable<int> idsDetalleActuales)
    {
        var idTexto = id.ToString();
        var idsDetalleTexto = idsDetalleActuales.Select(x => x.ToString()).ToList();

        return await _context.RegistrosAuditoria
            .Include(r => r.Usuario)
            .Where(r => (r.Entidad == entidadPrincipal && r.EntidadId == idTexto)
                        || (r.Entidad == entidadDetalle && idsDetalleTexto.Contains(r.EntidadId)))
            .OrderByDescending(r => r.Fecha)
            .ThenByDescending(r => r.Id)
            .ToListAsync();
    }
}
