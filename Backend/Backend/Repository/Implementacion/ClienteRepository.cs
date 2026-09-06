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

    public override async Task<Cliente?> GetByIdAsync(int id) =>
        await DbSet.Include(c => c.Mercado).Include(c => c.Ruta)
            .Include(c => c.Distrito!).ThenInclude(d => d.Provincia!).ThenInclude(p => p.Departamento)
            .FirstOrDefaultAsync(c => c.Id == id);

    public override async Task<IEnumerable<Cliente>> GetAllAsync() =>
        await DbSet.Include(c => c.Mercado).Include(c => c.Ruta)
            .Include(c => c.Distrito!).ThenInclude(d => d.Provincia!).ThenInclude(p => p.Departamento)
            .ToListAsync();

    public async Task<Cliente?> GetByDocumentoAsync(string documento)
    {
        return await DbSet.FirstOrDefaultAsync(c => c.Documento == documento);
    }

    public async Task<bool> ExistsByDocumentoAsync(string documento, int? excludeId = null)
    {
        return await DbSet.AnyAsync(c => c.Documento == documento && c.Id != excludeId);
    }

    public async Task DeleteAsync(Cliente entidad)
    {
        DbSet.Remove(entidad);
        await Context.SaveChangesAsync();
    }
}
