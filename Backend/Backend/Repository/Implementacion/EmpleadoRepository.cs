using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class EmpleadoRepository : Repository<Empleado>, IEmpleadoRepository
{
    public EmpleadoRepository(AppDbContext context) : base(context)
    {
    }

    public async Task<bool> ExistsByDocumentoAsync(string documento, int? excludeId = null)
    {
        return await DbSet.AnyAsync(e => e.Documento == documento && e.Id != excludeId);
    }

    /*
     * De una sola consulta, no uno por empleado.
     *
     * La lista de empleados muestra quién tiene cuenta, y preguntarlo fila por fila serían tantas
     * consultas como empleados.
     */
    public async Task<Dictionary<int, (int Id, string Nombre)>> UsuariosPorEmpleadoAsync()
    {
        var enlazados = await Context.Usuarios
            .Where(u => u.EmpleadoId != null)
            .Select(u => new { EmpleadoId = u.EmpleadoId!.Value, u.Id, u.Nombre })
            .AsNoTracking()
            .ToListAsync();

        return enlazados.ToDictionary(u => u.EmpleadoId, u => (u.Id, u.Nombre));
    }

    public async Task<Usuario?> UsuarioDeAsync(int empleadoId)
    {
        return await Context.Usuarios.AsNoTracking().FirstOrDefaultAsync(u => u.EmpleadoId == empleadoId);
    }

    public async Task DeleteAsync(Empleado entidad)
    {
        DbSet.Remove(entidad);
        await Context.SaveChangesAsync();
    }
}
