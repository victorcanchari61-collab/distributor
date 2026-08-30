using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class ClienteRepository : Repository<Cliente>, IClienteRepository
{
    public ClienteRepository(AppDbContext context) : base(context)
    {
    }

    public async Task<Cliente?> GetByRucAsync(string ruc)
    {
        return await DbSet.FirstOrDefaultAsync(c => c.Ruc == ruc);
    }

    public async Task<bool> ExistsByRucAsync(string ruc, int? excludeId = null)
    {
        return await DbSet.AnyAsync(c => c.Ruc == ruc && c.Id != excludeId);
    }
}
