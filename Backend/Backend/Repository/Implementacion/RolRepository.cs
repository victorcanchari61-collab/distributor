using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class RolRepository : Repository<Rol>, IRolRepository
{
    public RolRepository(AppDbContext context) : base(context)
    {
    }

    public async Task<IEnumerable<Rol>> GetAllConDetalleAsync()
    {
        return await DbSet
            .Include(r => r.Permisos)
            .Include(r => r.Usuarios)
            .OrderByDescending(r => r.DelSistema)
            .ThenBy(r => r.Nombre)
            .ToListAsync();
    }

    public async Task<Rol?> GetConPermisosAsync(int id)
    {
        return await DbSet.Include(r => r.Permisos).FirstOrDefaultAsync(r => r.Id == id);
    }

    public async Task<bool> ExistsByNombreAsync(string nombre, int? excludeId = null)
    {
        return await DbSet.AnyAsync(r => r.Nombre == nombre && r.Id != excludeId);
    }

    public async Task<int> ContarUsuariosAsync(int rolId)
    {
        return await Context.Usuarios.CountAsync(u => u.RolId == rolId);
    }

    public async Task ReemplazarPermisosAsync(int rolId, IEnumerable<RolPermiso> permisos)
    {
        await using var transaction = await Context.Database.BeginTransactionAsync();

        var actuales = await Context.RolPermisos.Where(p => p.RolId == rolId).ToListAsync();
        Context.RolPermisos.RemoveRange(actuales);

        // Que exista la fila ES el permiso: la ausencia significa "sin acceso",
        // asi la tabla no se llena de filas en cero.
        await Context.RolPermisos.AddRangeAsync(permisos);

        await Context.SaveChangesAsync();
        await transaction.CommitAsync();
    }

    public async Task DeleteAsync(Rol rol)
    {
        DbSet.Remove(rol);
        await Context.SaveChangesAsync();
    }
}
