using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class AsistenciaRepository : Repository<Asistencia>, IAsistenciaRepository
{
    public AsistenciaRepository(AppDbContext context) : base(context)
    {
    }

    private IQueryable<Asistencia> ConDetalle() =>
        DbSet.Include(a => a.Empleado).Include(a => a.Usuario);

    public async Task<Asistencia?> GetConDetalleAsync(int id) =>
        await ConDetalle().FirstOrDefaultAsync(a => a.Id == id);

    public async Task<List<Asistencia>> ListarAsync(DateTime desde, DateTime hasta, int? empleadoId)
    {
        var query = ConDetalle().Where(a => a.Fecha >= desde && a.Fecha <= hasta);
        if (empleadoId is int id) query = query.Where(a => a.EmpleadoId == id);

        return await query
            .OrderBy(a => a.Fecha)
            .ThenBy(a => a.Empleado!.Apellidos)
            .AsNoTracking()
            .ToListAsync();
    }

    public async Task<bool> ExisteActivaAsync(int empleadoId, DateTime fecha) =>
        await DbSet.AnyAsync(a => a.EmpleadoId == empleadoId && a.Fecha == fecha && !a.Anulado);
}
