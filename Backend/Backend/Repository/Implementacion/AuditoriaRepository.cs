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

    /// <summary>
    /// Cuántos registros se borran por vuelta. Un solo DELETE sobre cientos de
    /// miles de filas mantiene la tabla bloqueada todo ese rato y frena a quien
    /// esté guardando; en lotes el bloqueo dura lo que dura cada uno.
    /// </summary>
    private const int LoteBorrado = 5000;

    public async Task<(List<AuditoriaFilaResponse> Items, int Total)> ListarAsync(ConsultaTablaRequest consulta)
    {
        // Sin Include: la fila se proyecta al final y no trae los valores (el
        // registro entero en un alta o una baja), solo cuántos campos son.
        var query = Filtrar(_context.RegistrosAuditoria.AsNoTracking(), consulta);

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

        return await query
            .Select(r => new AuditoriaFilaResponse
            {
                Id = r.Id,
                Fecha = r.Fecha,
                UsuarioId = r.UsuarioId,
                Usuario = r.Usuario != null ? r.Usuario.Nombre : "Sistema",
                Entidad = r.Entidad,
                EntidadId = r.EntidadId,
                Accion = r.Accion,
                // Las claves del JSON, contadas en la base.
                Campos = FuncionesSql.JsonLength(r.ValoresNuevos ?? r.ValoresAnteriores) ?? 0,
            })
            .PaginarAsync(consulta);
    }

    /// <summary>
    /// Los registros que casan con el buscador y los filtros de la tabla, sin
    /// orden ni página. Lo usan el listado y el borrado masivo: el segundo
    /// tiene que borrar exactamente lo que el primero le mostró a la persona.
    /// </summary>
    private static IQueryable<RegistroAuditoria> Filtrar(
        IQueryable<RegistroAuditoria> query, ConsultaTablaRequest consulta)
    {
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

        // La fecha se guarda en UTC pero la persona filtra por día de calle: sin
        // pasarla a UTC, "hasta el 15" dejaba fuera lo de la noche del 15 y
        // "desde el 15" traía desde las 7 de la noche del 14. Con el borrado
        // masivo por fecha eso sería borrar el día equivocado.
        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null)
        {
            var desdeUtc = Zona.AUtc(desde.Value);
            query = query.Where(r => r.Fecha >= desdeUtc);
        }

        if (hasta is not null)
        {
            var hastaUtc = Zona.AUtc(hasta.Value);
            query = query.Where(r => r.Fecha <= hastaUtc);
        }

        return query;
    }

    public async Task<int> EliminarAsync(ConsultaTablaRequest consulta)
    {
        var filtradas = Filtrar(_context.RegistrosAuditoria.AsNoTracking(), consulta);
        var eliminados = 0;

        while (true)
        {
            // Primero los ids y luego el borrado por id: filtrar directo en el
            // DELETE obligaria a MySQL a leer la misma tabla que borra (por el
            // join con Usuarios) y no lo permite.
            var ids = await filtradas
                .OrderBy(r => r.Id)
                .Select(r => r.Id)
                .Take(LoteBorrado)
                .ToListAsync();

            if (ids.Count == 0) break;

            var borrados = await _context.RegistrosAuditoria
                .Where(r => ids.Contains(r.Id))
                .ExecuteDeleteAsync();

            // Otra persona pudo borrarlos a la vez; sin esto el ciclo no termina.
            if (borrados == 0) break;

            eliminados += borrados;
        }

        return eliminados;
    }

    public async Task AgregarAsync(RegistroAuditoria registro)
    {
        _context.RegistrosAuditoria.Add(registro);
        await _context.SaveChangesAsync();
    }

    public async Task<ResumenAuditoriaResponse> ResumenAsync()
    {
        // Los cuatro contadores de una pasada, agrupando por acción.
        var porAccion = await _context.RegistrosAuditoria
            .GroupBy(r => r.Accion)
            .Select(g => new { Accion = g.Key, Cantidad = g.Count() })
            .ToDictionaryAsync(x => x.Accion, x => x.Cantidad);

        return new ResumenAuditoriaResponse
        {
            Total = porAccion.Values.Sum(),
            Creados = porAccion.GetValueOrDefault(AccionAuditoria.Creado),
            Actualizados = porAccion.GetValueOrDefault(AccionAuditoria.Actualizado),
            Eliminados = porAccion.GetValueOrDefault(AccionAuditoria.Eliminado),
            // Por el índice (Entidad, EntidadId): no recorre los valores.
            Entidades = await _context.RegistrosAuditoria
                .Select(r => r.Entidad).Distinct().OrderBy(e => e).ToListAsync(),
            // Desde los usuarios, que son pocos: "¿tiene algún registro?" va por el índice.
            Usuarios = await _context.Usuarios
                .Where(u => _context.RegistrosAuditoria.Any(r => r.UsuarioId == u.Id))
                .Select(u => u.Nombre)
                .Distinct().OrderBy(u => u).ToListAsync(),
        };
    }

    public async Task<RegistroAuditoria?> GetPorIdAsync(int id) =>
        await _context.RegistrosAuditoria
            .AsNoTracking()
            .Include(r => r.Usuario)
            .FirstOrDefaultAsync(r => r.Id == id);

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
