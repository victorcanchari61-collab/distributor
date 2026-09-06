using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Backend.Repository.Implementacion;

public class VentasRepository : IVentasRepository
{
    private readonly AppDbContext _context;

    public VentasRepository(AppDbContext context)
    {
        _context = context;
    }

    public Task<IDbContextTransaction> IniciarTransaccionAsync() =>
        _context.Database.BeginTransactionAsync();

    public Task GuardarAsync() => _context.SaveChangesAsync();

    // --------------------------------------------------------------- Pedidos

    public async Task<string> SiguienteNumeroPedidoAsync()
    {
        var ultimo = await _context.Pedidos
            .OrderByDescending(p => p.Id)
            .Select(p => p.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"PD-{correlativo:D4}";
    }

    public async Task<Pedido> AddPedidoAsync(Pedido pedido)
    {
        await _context.Pedidos.AddAsync(pedido);
        await _context.SaveChangesAsync();
        return pedido;
    }

    private IQueryable<Pedido> PedidosConDetalle() =>
        _context.Pedidos
            .Include(p => p.Cliente)
            .Include(p => p.ListaPrecio)
            .Include(p => p.Almacen)
            .Include(p => p.Usuario)
            .Include(p => p.Detalle).ThenInclude(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(p => p.Detalle).ThenInclude(d => d.Presentacion);

    public async Task<Pedido?> GetPedidoAsync(int id) =>
        await PedidosConDetalle().FirstOrDefaultAsync(p => p.Id == id);

    public async Task<IEnumerable<Pedido>> GetPedidosAsync(string? estado = null) =>
        await PedidosConDetalle()
            .Where(p => estado == null || p.Estado == estado)
            .OrderByDescending(p => p.Fecha)
            .ThenByDescending(p => p.Id)
            .Take(300)
            .ToListAsync();

    public async Task UpdatePedidoAsync(Pedido pedido)
    {
        _context.Pedidos.Update(pedido);
        await _context.SaveChangesAsync();
    }

    /// <summary>
    /// Actualiza línea por línea en vez de borrar todo y recrearlo: así una
    /// edición de cantidad queda en la auditoría como "cantidad: 2 → 5" sobre
    /// la misma fila, no como un ELIMINADO + CREADO. Una línea que ya no
    /// viene en la lista nueva tampoco se borra — queda Anulada, para no
    /// perder su historial (regla del negocio: nunca se elimina, se anula).
    /// </summary>
    public async Task ReemplazarDetallePedidoAsync(int pedidoId, IEnumerable<PedidoDetalle> detalle)
    {
        var actuales = await _context.PedidoDetalles
            .Where(d => d.PedidoId == pedidoId)
            .ToListAsync();
        var actualesPorId = actuales.ToDictionary(d => d.Id);

        var conservadas = new HashSet<int>();

        foreach (var linea in detalle)
        {
            if (linea.Id > 0 && actualesPorId.TryGetValue(linea.Id, out var existente))
            {
                existente.ProductoId = linea.ProductoId;
                existente.PresentacionId = linea.PresentacionId;
                existente.CantidadPresentacion = linea.CantidadPresentacion;
                existente.Cantidad = linea.Cantidad;
                existente.PrecioUnitario = linea.PrecioUnitario;
                existente.Anulado = linea.Anulado;
                conservadas.Add(existente.Id);
            }
            else
            {
                linea.PedidoId = pedidoId;
                linea.Id = 0;
                await _context.PedidoDetalles.AddAsync(linea);
            }
        }

        foreach (var quitada in actuales.Where(d => !conservadas.Contains(d.Id)))
        {
            quitada.Anulado = true;
        }

        await _context.SaveChangesAsync();
    }

    public async Task<Dictionary<int, decimal>> GetReservadoPorProductoAsync(int? almacenId) =>
        await _context.PedidoDetalles
            .Where(d => d.Pedido!.Estado == EstadoPedido.Pendiente
                        && d.Pedido.ReservaStock
                        && !d.Anulado
                        && (almacenId == null || d.Pedido.AlmacenId == almacenId))
            .GroupBy(d => d.ProductoId)
            .Select(g => new { ProductoId = g.Key, Cantidad = g.Sum(d => d.Cantidad) })
            .ToDictionaryAsync(x => x.ProductoId, x => x.Cantidad);

    // ---------------------------------------------------------- Notas de venta

    public async Task<string> SiguienteNumeroNotaVentaAsync()
    {
        var ultimo = await _context.NotasVenta
            .OrderByDescending(n => n.Id)
            .Select(n => n.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"NV-{correlativo:D4}";
    }

    public async Task<NotaVenta> AddNotaVentaAsync(NotaVenta notaVenta)
    {
        await _context.NotasVenta.AddAsync(notaVenta);
        await _context.SaveChangesAsync();
        return notaVenta;
    }

    private IQueryable<NotaVenta> NotasVentaConDetalle() =>
        _context.NotasVenta
            .Include(n => n.Cliente)
            .Include(n => n.Pedido)
            .Include(n => n.Almacen)
            .Include(n => n.Usuario)
            .Include(n => n.Pagos).ThenInclude(p => p.MetodoPago)
            .Include(n => n.Pagos).ThenInclude(p => p.Usuario)
            .Include(n => n.Detalle).ThenInclude(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(n => n.Detalle).ThenInclude(d => d.Presentacion);

    public async Task<NotaVenta?> GetNotaVentaAsync(int id) =>
        await NotasVentaConDetalle().FirstOrDefaultAsync(n => n.Id == id);

    public async Task<IEnumerable<NotaVenta>> GetNotasVentaAsync(string? estado = null) =>
        await NotasVentaConDetalle()
            .Where(n => estado == null || n.Estado == estado)
            .OrderByDescending(n => n.Fecha)
            .ThenByDescending(n => n.Id)
            .Take(300)
            .ToListAsync();

    public async Task UpdateNotaVentaAsync(NotaVenta notaVenta)
    {
        _context.NotasVenta.Update(notaVenta);
        await _context.SaveChangesAsync();
    }

    public async Task<NotaVentaDetalle?> GetNotaVentaDetalleConNotaVentaAsync(int id) =>
        await _context.NotaVentaDetalles
            .Include(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(d => d.NotaVenta)
            .FirstOrDefaultAsync(d => d.Id == id);
}
