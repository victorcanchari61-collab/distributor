using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class FinanzasRepository : IFinanzasRepository
{
    private readonly AppDbContext _context;

    public FinanzasRepository(AppDbContext context)
    {
        _context = context;
    }

    // --- Métodos de pago ---

    public async Task<IEnumerable<MetodoPago>> GetMetodosPagoAsync() =>
        await _context.MetodosPago
            .OrderByDescending(m => m.Activo)
            .ThenBy(m => m.Nombre)
            .ToListAsync();

    public async Task<MetodoPago?> GetMetodoPagoAsync(int id) =>
        await _context.MetodosPago.FirstOrDefaultAsync(m => m.Id == id);

    public async Task<bool> ExisteNombreMetodoPagoAsync(string nombre, int? excepto = null) =>
        await _context.MetodosPago.AnyAsync(m =>
            m.Nombre == nombre && (excepto == null || m.Id != excepto));

    public async Task<MetodoPago> AddMetodoPagoAsync(MetodoPago metodo)
    {
        await _context.MetodosPago.AddAsync(metodo);
        await _context.SaveChangesAsync();
        return metodo;
    }

    public async Task UpdateMetodoPagoAsync(MetodoPago metodo)
    {
        _context.MetodosPago.Update(metodo);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteMetodoPagoAsync(MetodoPago metodo)
    {
        _context.MetodosPago.Remove(metodo);
        await _context.SaveChangesAsync();
    }

    public async Task<int> ContarUsosMetodoPagoAsync(int metodoPagoId) =>
        await _context.CompraPagos.CountAsync(p => p.MetodoPagoId == metodoPagoId);

    // --- Arqueo de caja ---

    public async Task<decimal> GetCobradoEfectivoAsync(DateTime fecha) =>
        await _context.PagosVenta
            .Where(p => !p.Anulado
                        && p.MetodoPago!.Tipo == TipoMetodoPago.Efectivo
                        && p.NotaVenta!.Estado == EstadoNotaVenta.Confirmada
                        && p.Fecha.Date == fecha.Date)
            .SumAsync(p => (decimal?)p.Monto) ?? 0;

    public async Task<decimal> GetPagadoEfectivoAsync(DateTime fecha) =>
        await _context.CompraPagos
            .Where(p => !p.Anulado
                        && p.MetodoPago!.Tipo == TipoMetodoPago.Efectivo
                        && p.Compra!.Estado != EstadoCompra.Anulada
                        && p.Fecha.Date == fecha.Date)
            .SumAsync(p => (decimal?)p.Monto) ?? 0;

    public async Task<ArqueoCaja?> GetArqueoAsync(DateTime fecha) =>
        await _context.ArqueosCaja
            .Include(a => a.Usuario)
            .FirstOrDefaultAsync(a => a.Fecha.Date == fecha.Date);

    public async Task<IEnumerable<ArqueoCaja>> GetHistorialArqueoAsync() =>
        await _context.ArqueosCaja
            .Include(a => a.Usuario)
            .OrderByDescending(a => a.Fecha)
            .Take(90)
            .ToListAsync();

    public async Task<ArqueoCaja> GuardarArqueoAsync(ArqueoCaja arqueo)
    {
        var existente = await _context.ArqueosCaja.FirstOrDefaultAsync(a => a.Fecha.Date == arqueo.Fecha.Date);
        if (existente is null)
        {
            await _context.ArqueosCaja.AddAsync(arqueo);
        }
        else
        {
            existente.MontoEsperado = arqueo.MontoEsperado;
            existente.MontoContado = arqueo.MontoContado;
            existente.Observacion = arqueo.Observacion;
            existente.UsuarioId = arqueo.UsuarioId;
            existente.FechaCreacion = DateTime.UtcNow;
            arqueo = existente;
        }

        await _context.SaveChangesAsync();
        return arqueo;
    }
}
