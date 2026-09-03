using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Backend.Repository.Implementacion;

public class ComprasRepository : IComprasRepository
{
    private readonly AppDbContext _context;

    public ComprasRepository(AppDbContext context)
    {
        _context = context;
    }

    public Task<IDbContextTransaction> IniciarTransaccionAsync() =>
        _context.Database.BeginTransactionAsync();

    public Task GuardarAsync() => _context.SaveChangesAsync();

    // ------------------------------------------------------- Ordenes de compra

    public async Task<string> SiguienteNumeroOrdenAsync()
    {
        var ultimo = await _context.OrdenesCompra
            .OrderByDescending(o => o.Id)
            .Select(o => o.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"OC-{correlativo:D6}";
    }

    public async Task<OrdenCompra> AddOrdenAsync(OrdenCompra orden)
    {
        await _context.OrdenesCompra.AddAsync(orden);
        await _context.SaveChangesAsync();
        return orden;
    }

    private IQueryable<OrdenCompra> OrdenesConDetalle() =>
        _context.OrdenesCompra
            .Include(o => o.Proveedor)
            .Include(o => o.Usuario)
            .Include(o => o.Detalle).ThenInclude(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(o => o.Detalle).ThenInclude(d => d.Presentacion);

    public async Task<OrdenCompra?> GetOrdenAsync(int id) =>
        await OrdenesConDetalle().FirstOrDefaultAsync(o => o.Id == id);

    public async Task<IEnumerable<OrdenCompra>> GetOrdenesAsync(string? estado = null) =>
        await OrdenesConDetalle()
            .Where(o => estado == null || o.Estado == estado)
            .OrderByDescending(o => o.Fecha)
            .ThenByDescending(o => o.Id)
            .Take(300)
            .ToListAsync();

    public async Task UpdateOrdenAsync(OrdenCompra orden)
    {
        _context.OrdenesCompra.Update(orden);
        await _context.SaveChangesAsync();
    }

    public async Task ReemplazarDetalleOrdenAsync(int ordenId, IEnumerable<OrdenCompraDetalle> detalle)
    {
        var actuales = await _context.OrdenCompraDetalles
            .Where(d => d.OrdenCompraId == ordenId)
            .ToListAsync();

        _context.OrdenCompraDetalles.RemoveRange(actuales);
        await _context.OrdenCompraDetalles.AddRangeAsync(detalle);
        await _context.SaveChangesAsync();
    }

    // ------------------------------------------------------------------ Compras

    public async Task<string> SiguienteNumeroCompraAsync()
    {
        var ultimo = await _context.Compras
            .OrderByDescending(c => c.Id)
            .Select(c => c.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"CP-{correlativo:D6}";
    }

    public async Task<Compra> AddCompraAsync(Compra compra)
    {
        await _context.Compras.AddAsync(compra);
        await _context.SaveChangesAsync();
        return compra;
    }

    private IQueryable<Compra> ComprasConDetalle() =>
        _context.Compras
            .Include(c => c.Proveedor)
            .Include(c => c.OrdenCompra)
            .Include(c => c.Usuario)
            .Include(c => c.MetodoPago)
            .Include(c => c.Detalle).ThenInclude(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(c => c.Detalle).ThenInclude(d => d.Presentacion);

    public async Task<Compra?> GetCompraAsync(int id) =>
        await ComprasConDetalle().FirstOrDefaultAsync(c => c.Id == id);

    public async Task<IEnumerable<Compra>> GetComprasAsync(string? estado = null) =>
        await ComprasConDetalle()
            .Where(c => estado == null || c.Estado == estado)
            .OrderByDescending(c => c.Fecha)
            .ThenByDescending(c => c.Id)
            .Take(300)
            .ToListAsync();

    public async Task UpdateCompraAsync(Compra compra)
    {
        _context.Compras.Update(compra);
        await _context.SaveChangesAsync();
    }

    public async Task<CompraDetalle?> GetCompraDetalleConCompraAsync(int id) =>
        await _context.CompraDetalles
            .Include(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(d => d.Compra).ThenInclude(c => c!.Detalle)
            .FirstOrDefaultAsync(d => d.Id == id);
}
