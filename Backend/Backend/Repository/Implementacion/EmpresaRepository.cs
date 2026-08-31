using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class EmpresaRepository : Repository<Empresa>, IEmpresaRepository
{
    public EmpresaRepository(AppDbContext context) : base(context)
    {
    }

    public async Task<Empresa?> GetActivaAsync()
    {
        return await DbSet.FirstOrDefaultAsync(e => e.Activa);
    }

    public async Task<bool> ExistsByRucAsync(string ruc, int? excludeId = null)
    {
        return await DbSet.AnyAsync(e => e.Ruc == ruc && e.Id != excludeId);
    }

    public async Task<bool> AnyAsync()
    {
        return await DbSet.AnyAsync();
    }

    public async Task SetActivaAsync(int id)
    {
        // Dos guardados dentro de una misma transaccion, en este orden: primero
        // apagar las otras, despues encender la elegida. Si se hiciera en un
        // solo SaveChanges habria un instante con dos filas activas y el indice
        // unico de la tabla lo rechazaria.
        await using var transaction = await Context.Database.BeginTransactionAsync();

        var otras = await DbSet.Where(e => e.Activa && e.Id != id).ToListAsync();
        if (otras.Count > 0)
        {
            foreach (var otra in otras)
            {
                otra.Activa = false;
            }

            await Context.SaveChangesAsync();
        }

        var elegida = await DbSet.FirstAsync(e => e.Id == id);
        elegida.Activa = true;
        await Context.SaveChangesAsync();

        await transaction.CommitAsync();
    }

    public async Task DeleteAsync(Empresa empresa)
    {
        DbSet.Remove(empresa);
        await Context.SaveChangesAsync();
    }
}
