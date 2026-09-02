using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class UsuarioRepository : Repository<Usuario>, IUsuarioRepository
{
    public UsuarioRepository(AppDbContext context) : base(context)
    {
    }

    public async Task<Usuario?> GetByEmailAsync(string email)
    {
        // Include del rol: el token necesita su nombre para las autorizaciones.
        return await DbSet.Include(u => u.Rol).FirstOrDefaultAsync(u => u.Email == email);
    }

    public async Task<IEnumerable<Usuario>> GetAllConRolAsync()
    {
        // Activos primero: los desactivados siguen listandose para poder
        // volver a habilitarlos, igual que en clientes y proveedores.
        return await DbSet.Include(u => u.Rol)
            .OrderByDescending(u => u.Activo)
            .ThenBy(u => u.Nombre)
            .ToListAsync();
    }

    public async Task<Usuario?> GetByIdConRolAsync(int id)
    {
        return await DbSet.Include(u => u.Rol).FirstOrDefaultAsync(u => u.Id == id);
    }

    public async Task<Rol?> GetRolAsync(int rolId)
    {
        return await Context.Roles.FirstOrDefaultAsync(r => r.Id == rolId);
    }
}
