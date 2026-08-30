using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class ProveedorRepository : Repository<Proveedor>, IProveedorRepository
{
    public ProveedorRepository(AppDbContext context) : base(context)
    {
    }

    public async Task<Proveedor?> GetByRucAsync(string ruc)
    {
        return await DbSet.FirstOrDefaultAsync(p => p.Ruc == ruc);
    }

    public async Task<bool> ExistsByRucAsync(string ruc, int? excludeId = null)
    {
        return await DbSet.AnyAsync(p => p.Ruc == ruc && p.Id != excludeId);
    }
}
