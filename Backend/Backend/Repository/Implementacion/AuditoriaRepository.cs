using Backend.Data;
using Backend.Models;
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
