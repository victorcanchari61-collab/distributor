using Backend.Data;
using Backend.Models;
using Microsoft.EntityFrameworkCore;
using Backend.Repository.Interfaces;

namespace Backend.Repository.Implementacion;

public class MercadoRepository : IMercadoRepository
{
    private readonly AppDbContext _context;

    public MercadoRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<Dictionary<int, ResumenMercado>> ResumenPorMercadoAsync(DateTime inicioMesUtc, int? mercadoId = null)
    {
        var resumen = new Dictionary<int, ResumenMercado>();
        ResumenMercado De(int id) => resumen.TryGetValue(id, out var r) ? r : resumen[id] = new ResumenMercado();

        // Rutas: las de sus clientes activos, sin repetir.
        var rutas = await _context.Clientes.AsNoTracking()
            .Where(c => c.Activo && c.MercadoId != null && c.RutaId != null && (mercadoId == null || c.MercadoId == mercadoId))
            .Select(c => new { MercadoId = c.MercadoId!.Value, c.Ruta!.Nombre })
            .Distinct()
            .ToListAsync();
        foreach (var x in rutas) De(x.MercadoId).Rutas.Add(x.Nombre);

        // Ventas del mes y deuda: con la misma cuenta del total de una venta que en todo el sistema (líneas vigentes
        // menos recojos, a centavos). Se traen juntas las del mes y las de crédito, que son las que hacen falta.
        var notas = await _context.NotasVenta.AsNoTracking()
            .Where(n => n.Estado == EstadoNotaVenta.Confirmada && n.Cliente!.MercadoId != null
                        && (mercadoId == null || n.Cliente.MercadoId == mercadoId)
                        && (n.Fecha >= inicioMesUtc || n.FormaPago == FormaPagoVenta.Credito))
            .Select(n => new
            {
                MercadoId = n.Cliente!.MercadoId!.Value,
                DelMes = n.Fecha >= inicioMesUtc,
                Credito = n.FormaPago == FormaPagoVenta.Credito,
                Total = n.Detalle.Where(d => !d.Anulado).Sum(d => d.CantidadPresentacion * d.PrecioPresentacion)
                        - n.Recojos.Where(r => r.Estado != EstadoRecojo.Anulado).Sum(r => r.Importe),
                Pagado = n.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto),
            })
            .ToListAsync();
        foreach (var g in notas.GroupBy(n => n.MercadoId))
        {
            var r = De(g.Key);
            r.VentasMes = g.Where(n => n.DelMes).Sum(n => Math.Round(n.Total, 2));
            r.PorCobrar = Math.Round(
                g.Where(n => n.Credito).Select(n => Math.Round(n.Total, 2) - n.Pagado).Where(saldo => saldo > 0).Sum(), 2);
        }

        return resumen;
    }

    public async Task<IEnumerable<Mercado>> GetAllAsync() =>
        await _context.Mercados
            .OrderByDescending(m => m.Activo)
            .ThenBy(m => m.Nombre)
            .ToListAsync();

    public async Task<Mercado?> GetByIdAsync(int id) =>
        await _context.Mercados.FirstOrDefaultAsync(m => m.Id == id);

    public async Task<bool> ExisteNombreAsync(string nombre, int? excepto = null) =>
        await _context.Mercados.AnyAsync(m => m.Nombre == nombre && (excepto == null || m.Id != excepto));

    public async Task<int> ContarClientesAsync(int id) =>
        await _context.Clientes.CountAsync(c => c.MercadoId == id);

    public async Task<Dictionary<int, int>> ContarClientesPorMercadoAsync() =>
        await _context.Clientes
            .Where(c => c.MercadoId != null)
            .GroupBy(c => c.MercadoId!.Value)
            .Select(g => new { MercadoId = g.Key, Cantidad = g.Count() })
            .ToDictionaryAsync(x => x.MercadoId, x => x.Cantidad);

    public async Task<Mercado> AddAsync(Mercado mercado)
    {
        await _context.Mercados.AddAsync(mercado);
        await _context.SaveChangesAsync();
        return mercado;
    }

    public async Task UpdateAsync(Mercado mercado)
    {
        _context.Mercados.Update(mercado);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Mercado mercado)
    {
        _context.Mercados.Remove(mercado);
        await _context.SaveChangesAsync();
    }
}
