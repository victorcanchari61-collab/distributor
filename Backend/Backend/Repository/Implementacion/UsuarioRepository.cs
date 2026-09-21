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

    public async Task<Usuario?> GetByIdentificadorAsync(string identificador)
    {
        // El correo manda; el DNI es para quien no tiene. Se distinguen solos: un correo lleva arroba.
        var texto = identificador.Trim();
        return await DbSet.Include(u => u.Rol)
            .FirstOrDefaultAsync(u => u.Email == texto || (u.Dni != null && u.Dni == texto));
    }

    public async Task<Usuario?> GetByDniAsync(string dni) =>
        await DbSet.AsNoTracking().FirstOrDefaultAsync(u => u.Dni == dni);

    public async Task<IEnumerable<Usuario>> GetAllConRolAsync()
    {
        // Activos primero: los desactivados siguen listandose para poder
        // volver a habilitarlos, igual que en clientes y proveedores.
        return await DbSet.Include(u => u.Rol).Include(u => u.Empleado).Include(u => u.Ruta)
            .OrderByDescending(u => u.Activo)
            .ThenBy(u => u.Nombre)
            .ToListAsync();
    }

    public async Task<Usuario?> GetByIdConRolAsync(int id)
    {
        return await DbSet.Include(u => u.Rol).Include(u => u.Empleado).Include(u => u.Ruta)
            .FirstOrDefaultAsync(u => u.Id == id);
    }

    public async Task<Rol?> GetRolAsync(int rolId)
    {
        return await Context.Roles.FirstOrDefaultAsync(r => r.Id == rolId);
    }

    public async Task<Empleado?> GetEmpleadoAsync(int empleadoId)
    {
        return await Context.Empleados.FirstOrDefaultAsync(e => e.Id == empleadoId);
    }

    public async Task<Dictionary<int, string>> VendedoresPorRutaAsync()
    {
        var filas = await DbSet.AsNoTracking()
            .Where(u => u.Activo && u.RutaId != null)
            .Select(u => new { RutaId = u.RutaId!.Value, u.Nombre })
            .ToListAsync();
        return filas.GroupBy(f => f.RutaId)
            .ToDictionary(g => g.Key, g => string.Join(", ", g.Select(f => f.Nombre).OrderBy(n => n)));
    }

    public async Task<Ruta?> GetRutaAsync(int rutaId)
    {
        return await Context.Rutas.FirstOrDefaultAsync(r => r.Id == rutaId);
    }

    public async Task<Usuario?> GetUsuarioDeEmpleadoAsync(int empleadoId, int? excluirUsuarioId = null)
    {
        return await DbSet.AsNoTracking()
            .FirstOrDefaultAsync(u => u.EmpleadoId == empleadoId && u.Id != excluirUsuarioId);
    }
}
