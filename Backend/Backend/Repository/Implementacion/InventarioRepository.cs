using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class InventarioRepository : IInventarioRepository
{
    private readonly AppDbContext _context;

    public InventarioRepository(AppDbContext context)
    {
        _context = context;
    }

    // --- Almacenes ---

    public async Task<IEnumerable<Almacen>> GetAlmacenesAsync() =>
        await _context.Almacenes
            .OrderByDescending(a => a.Activo)
            .ThenByDescending(a => a.EsPrincipal)
            .ThenBy(a => a.Nombre)
            .ToListAsync();

    public async Task<Almacen?> GetAlmacenAsync(int id) =>
        await _context.Almacenes.FirstOrDefaultAsync(a => a.Id == id);

    public async Task<Almacen?> GetAlmacenPrincipalAsync() =>
        await _context.Almacenes
            .Where(a => a.Activo)
            .OrderByDescending(a => a.EsPrincipal)
            .ThenBy(a => a.Id)
            .FirstOrDefaultAsync();

    public async Task<bool> ExisteCodigoAlmacenAsync(string codigo, int? excepto = null) =>
        await _context.Almacenes.AnyAsync(a =>
            a.Codigo == codigo && (excepto == null || a.Id != excepto));

    public async Task<Almacen> AddAlmacenAsync(Almacen almacen)
    {
        await _context.Almacenes.AddAsync(almacen);
        await _context.SaveChangesAsync();
        return almacen;
    }

    public async Task UpdateAlmacenAsync(Almacen almacen)
    {
        _context.Almacenes.Update(almacen);
        await _context.SaveChangesAsync();
    }

    public async Task<int> ContarCapasAlmacenAsync(int almacenId) =>
        await _context.CapasCosto.CountAsync(c => c.AlmacenId == almacenId);

    public async Task DeleteAlmacenAsync(Almacen almacen)
    {
        _context.Almacenes.Remove(almacen);
        await _context.SaveChangesAsync();
    }

    // --- Capas ---

    private IQueryable<CapaCosto> Capas(int productoId, int? almacenId) =>
        _context.CapasCosto
            .Include(c => c.Almacen)
            .Where(c => c.ProductoId == productoId
                        && (almacenId == null || c.AlmacenId == almacenId));

    public async Task<List<CapaCosto>> GetCapasDisponiblesAsync(int productoId, int? almacenId = null) =>
        await Capas(productoId, almacenId)
            .Where(c => c.CantidadDisponible > 0)
            // Primero la mas antigua: es la que sale primero del almacen.
            .OrderBy(c => c.Fecha)
            .ThenBy(c => c.Id)
            .ToListAsync();

    public async Task<List<CapaCosto>> GetCapasAsync(int productoId, int? almacenId = null) =>
        await Capas(productoId, almacenId)
            .OrderBy(c => c.Fecha)
            .ThenBy(c => c.Id)
            .ToListAsync();

    public async Task<CapaCosto?> GetUltimaCapaAsync(int productoId, int? almacenId = null) =>
        await Capas(productoId, almacenId)
            .OrderByDescending(c => c.Fecha)
            .ThenByDescending(c => c.Id)
            .FirstOrDefaultAsync();

    public async Task<CapaCosto> AddCapaAsync(CapaCosto capa)
    {
        await _context.CapasCosto.AddAsync(capa);
        await _context.SaveChangesAsync();
        return capa;
    }

    public Task GuardarCambiosAsync() => _context.SaveChangesAsync();

    public async Task<Dictionary<int, ResumenStock>> GetResumenAsync(
        IEnumerable<int> productoIds)
    {
        var ids = productoIds.ToList();

        var filas = await _context.CapasCosto
            .Where(c => ids.Contains(c.ProductoId) && c.CantidadDisponible > 0)
            .GroupBy(c => c.ProductoId)
            .Select(g => new
            {
                ProductoId = g.Key,
                Stock = g.Sum(c => c.CantidadDisponible),
                Valorizado = g.Sum(c => c.CantidadDisponible * c.CostoUnitario),
                // El rango deja ver de un vistazo que conviven dos costos.
                CostoMin = g.Min(c => c.CostoUnitario),
                CostoMax = g.Max(c => c.CostoUnitario)
            })
            .ToListAsync();

        return filas.ToDictionary(
            f => f.ProductoId,
            f => new ResumenStock(f.Stock, f.Valorizado, f.CostoMin, f.CostoMax));
    }
}
