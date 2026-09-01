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

    public async Task<Proveedor?> GetByDocumentoAsync(string documento)
    {
        return await DbSet.FirstOrDefaultAsync(p => p.Documento == documento);
    }

    public async Task<bool> ExistsByDocumentoAsync(string documento, int? excludeId = null)
    {
        return await DbSet.AnyAsync(p => p.Documento == documento && p.Id != excludeId);
    }
}
