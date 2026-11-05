using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class CatalogoClienteRepository : ICatalogoClienteRepository
{
    private readonly AppDbContext _context;

    public CatalogoClienteRepository(AppDbContext context)
    {
        _context = context;
    }

    public Task<List<ListaPrecio>> GetListasActivasAsync() =>
        _context.ListasPrecio
            .AsNoTracking()
            .Where(l => l.Activo)
            .OrderByDescending(l => l.EsPredeterminada)
            .ThenBy(l => l.Nombre)
            .ToListAsync();

    public Task<List<Producto>> GetProductosActivosAsync() =>
        _context.Productos
            .AsNoTracking()
            .Where(p => p.Activo)
            .Include(p => p.Categoria)
            .Include(p => p.Marca)
            .Include(p => p.UnidadBase)
            .Include(p => p.ContenidoUnidad)
            .Include(p => p.Presentaciones).ThenInclude(x => x.Unidad)
            .OrderBy(p => p.Nombre)
            .ToListAsync();

    public Task<List<PrecioProducto>> GetPreciosActivosAsync(int listaId) =>
        _context.Precios
            .AsNoTracking()
            .Where(p => p.ListaPrecioId == listaId && p.Activo)
            .ToListAsync();
}
