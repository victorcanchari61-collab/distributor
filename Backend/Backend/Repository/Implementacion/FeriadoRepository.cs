using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class FeriadoRepository : Repository<Feriado>, IFeriadoRepository
{
    public FeriadoRepository(AppDbContext context) : base(context)
    {
    }

    public async Task<bool> ExistsByFechaAsync(DateTime fecha, int? excludeId = null) =>
        await DbSet.AnyAsync(f => f.Fecha == fecha && f.Id != excludeId);

    public async Task DeleteAsync(Feriado entidad)
    {
        DbSet.Remove(entidad);
        await Context.SaveChangesAsync();
    }
}
