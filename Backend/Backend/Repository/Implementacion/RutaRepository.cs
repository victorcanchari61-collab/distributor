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

    public async Task<Dictionary<int, ResumenRuta>> ResumenPorRutaAsync(DateTime inicioMesUtc, int? rutaId = null)
    {
        var resumen = new Dictionary<int, ResumenRuta>();
        ResumenRuta De(int id) => resumen.TryGetValue(id, out var r) ? r : resumen[id] = new ResumenRuta();

        // Mercados: los de sus clientes activos, sin repetir.
        var mercados = await _context.Clientes.AsNoTracking()
            .Where(c => c.Activo && c.RutaId != null && c.MercadoId != null && (rutaId == null || c.RutaId == rutaId))
            .Select(c => new { RutaId = c.RutaId!.Value, c.Mercado!.Nombre })
            .Distinct()
            .ToListAsync();
        foreach (var m in mercados.OrderBy(m => m.Nombre)) De(m.RutaId).Mercados.Add(m.Nombre);

        // Salidas: día y camión, de los recorridos de Flota.
        var salidas = await _context.RecorridosVehiculo.AsNoTracking()
            .Where(r => rutaId == null || r.RutaId == rutaId)
            .Select(r => new { r.RutaId, r.Dia, r.Vehiculo!.Placa })
            .ToListAsync();
        foreach (var x in salidas.OrderBy(x => Array.IndexOf(DiaSemana.Todos, x.Dia)).ThenBy(x => x.Placa))
            De(x.RutaId).Salidas.Add((x.Dia, x.Placa));

        // Ventas del mes: el total de cada venta con la misma cuenta que en todo el sistema (líneas vigentes menos
        // recojos, a centavos). Incluye las facturas y boletas directas, que también son ventas.
        var ventas = await _context.NotasVenta.AsNoTracking()
            .Where(n => n.Estado == EstadoNotaVenta.Confirmada && n.Fecha >= inicioMesUtc && n.Cliente!.RutaId != null
                        && (rutaId == null || n.Cliente.RutaId == rutaId))
            .Select(n => new
            {
                RutaId = n.Cliente!.RutaId!.Value,
                n.ClienteId,
                Total = n.Detalle.Where(d => !d.Anulado).Sum(d => d.CantidadPresentacion * d.PrecioPresentacion)
                        - n.Recojos.Where(r => r.Estado != EstadoRecojo.Anulado).Sum(r => r.Importe),
            })
            .ToListAsync();
        foreach (var g in ventas.GroupBy(v => v.RutaId))
        {
            var r = De(g.Key);
            r.VentasMes = g.Sum(v => Math.Round(v.Total, 2));
            r.ClientesConCompraMes = g.Select(v => v.ClienteId).Distinct().Count();
        }

        // Deuda: ventas al crédito con saldo, igual que Cuentas por cobrar.
        var credito = await _context.NotasVenta.AsNoTracking()
            .Where(n => n.Estado == EstadoNotaVenta.Confirmada && n.FormaPago == FormaPagoVenta.Credito
                        && n.Cliente!.RutaId != null && (rutaId == null || n.Cliente.RutaId == rutaId))
            .Select(n => new
            {
                RutaId = n.Cliente!.RutaId!.Value,
                n.ClienteId,
                Total = n.Detalle.Where(d => !d.Anulado).Sum(d => d.CantidadPresentacion * d.PrecioPresentacion)
                        - n.Recojos.Where(r => r.Estado != EstadoRecojo.Anulado).Sum(r => r.Importe),
                Pagado = n.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto),
            })
            .ToListAsync();
        var conSaldo = credito
            .Select(n => new { n.RutaId, n.ClienteId, Saldo = Math.Round(n.Total, 2) - n.Pagado })
            .Where(n => n.Saldo > 0);
        foreach (var g in conSaldo.GroupBy(n => n.RutaId))
        {
            var r = De(g.Key);
            r.PorCobrar = Math.Round(g.Sum(n => n.Saldo), 2);
            r.ClientesConDeuda = g.Select(n => n.ClienteId).Distinct().Count();
        }

        return resumen;
    }

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
