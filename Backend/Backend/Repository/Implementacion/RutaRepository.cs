using Backend.Data;
using Backend.Models;
using Microsoft.EntityFrameworkCore;
using Backend.Repository.Interfaces;

namespace Backend.Repository.Implementacion;

public class RutaRepository : IRutaRepository
{
    private readonly AppDbContext _context;

    public RutaRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Ruta>> GetAllAsync() =>
        await _context.Rutas
            .OrderByDescending(r => r.Activo)
            .ThenBy(r => r.Nombre)
            .ToListAsync();

    public async Task<Ruta?> GetByIdAsync(int id) =>
        await _context.Rutas.FirstOrDefaultAsync(r => r.Id == id);

    public async Task<bool> ExisteNombreAsync(string nombre, int? excepto = null) =>
        await _context.Rutas.AnyAsync(r => r.Nombre == nombre && (excepto == null || r.Id != excepto));

    public async Task<int> ContarClientesAsync(int id) =>
        await _context.Clientes.CountAsync(c => c.RutaId == id);

    public async Task<Dictionary<int, int>> ContarClientesPorRutaAsync() =>
        await _context.Clientes
            .Where(c => c.RutaId != null)
            .GroupBy(c => c.RutaId!.Value)
            .Select(g => new { RutaId = g.Key, Cantidad = g.Count() })
            .ToDictionaryAsync(x => x.RutaId, x => x.Cantidad);

    public async Task<Dictionary<int, List<string>>> VendedoresPorRutaAsync() =>
        (await _context.UsuarioRutas.AsNoTracking()
            .OrderByDescending(r => r.Usuario!.Activo).ThenBy(r => r.Usuario!.Nombre)
            .Select(r => new { r.RutaId, r.Usuario!.Nombre })
            .ToListAsync())
        .GroupBy(x => x.RutaId)
        .ToDictionary(g => g.Key, g => g.Select(x => x.Nombre).ToList());

    public async Task<int> ContarUsosEnRepartoAsync(int id) =>
        await _context.RecorridosVehiculo.CountAsync(r => r.RutaId == id)
        + await _context.Set<DespachoRuta>().CountAsync(d => d.RutaId == id)
        + await _context.Despachos.CountAsync(d => d.RutaId == id);

    public async Task<List<string>> VendedoresAsync(int id) =>
        await _context.UsuarioRutas.AsNoTracking()
            .Where(r => r.RutaId == id)
            .OrderByDescending(r => r.Usuario!.Activo).ThenBy(r => r.Usuario!.Nombre)
            .Select(r => r.Usuario!.Nombre)
            .ToListAsync();

    public async Task<Ruta> AddAsync(Ruta ruta)
    {
        await _context.Rutas.AddAsync(ruta);
        await _context.SaveChangesAsync();
        return ruta;
    }

    public async Task UpdateAsync(Ruta ruta)
    {
        _context.Rutas.Update(ruta);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Ruta ruta)
    {
        _context.Rutas.Remove(ruta);
        await _context.SaveChangesAsync();
    }
}
