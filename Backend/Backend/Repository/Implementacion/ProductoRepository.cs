using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class ProductoRepository : IProductoRepository
{
    private readonly AppDbContext _context;

    public ProductoRepository(AppDbContext context)
    {
        _context = context;
    }

    private IQueryable<Producto> ConDetalle() => _context.Productos
        .Include(p => p.Categoria)
        .Include(p => p.Marca)
        .Include(p => p.UnidadBase)
        .Include(p => p.ContenidoUnidad)
        .Include(p => p.Presentaciones)
        .ThenInclude(pr => pr.Unidad);

    public async Task<IEnumerable<Producto>> GetAllConDetalleAsync()
    {
        return await ConDetalle()
            .OrderByDescending(p => p.Activo)
            .ThenBy(p => p.Nombre)
            .ToListAsync();
    }

    public async Task<Producto?> GetConDetalleAsync(int id) =>
        await ConDetalle().FirstOrDefaultAsync(p => p.Id == id);

    public async Task<Producto?> GetByCodigoAsync(string codigo) =>
        await ConDetalle().FirstOrDefaultAsync(p => p.Codigo == codigo);

    public async Task<bool> ExisteCodigoAsync(string codigo, int? excepto = null) =>
        await _context.Productos.AnyAsync(p =>
            p.Codigo == codigo && (excepto == null || p.Id != excepto));

    public async Task<Producto> AddAsync(Producto producto)
    {
        await _context.Productos.AddAsync(producto);
        await _context.SaveChangesAsync();
        return producto;
    }

    public async Task UpdateAsync(Producto producto)
    {
        _context.Productos.Update(producto);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Producto producto)
    {
        _context.Productos.Remove(producto);
        await _context.SaveChangesAsync();
    }

    // --- Presentaciones ---

    public async Task<ProductoPresentacion?> GetPresentacionAsync(int id) =>
        await _context.Presentaciones
            .Include(p => p.Unidad)
            .Include(p => p.Producto)
            .ThenInclude(pr => pr!.UnidadBase)
            .FirstOrDefaultAsync(p => p.Id == id);

    public async Task<ProductoPresentacion> AddPresentacionAsync(ProductoPresentacion presentacion)
    {
        await _context.Presentaciones.AddAsync(presentacion);
        await _context.SaveChangesAsync();
        return presentacion;
    }

    public async Task UpdatePresentacionAsync(ProductoPresentacion presentacion)
    {
        _context.Presentaciones.Update(presentacion);
        await _context.SaveChangesAsync();
    }

    public async Task DeletePresentacionAsync(ProductoPresentacion presentacion)
    {
        _context.Presentaciones.Remove(presentacion);
        await _context.SaveChangesAsync();
    }

    public async Task<int> ContarPreciosAsync(int presentacionId) =>
        await _context.Precios.CountAsync(p => p.PresentacionId == presentacionId);

    public async Task LimpiarPredeterminadaAsync(int productoId, int exceptoId, bool venta)
    {
        var otras = await _context.Presentaciones
            .Where(p => p.ProductoId == productoId && p.Id != exceptoId)
            .ToListAsync();

        foreach (var otra in otras)
        {
            if (venta)
            {
                otra.PredeterminadaVenta = false;
            }
            else
            {
                otra.PredeterminadaCompra = false;
            }
        }

        await _context.SaveChangesAsync();
    }
}
