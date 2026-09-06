using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Models;
using Backend.Repository;
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

    public async Task<(List<ArqueoCaja> Items, int Total)> ListarArqueosAsync(ConsultaTablaRequest consulta)
    {
        var query = _context.ArqueosCaja.Include(a => a.Usuario).AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(a => a.Usuario != null && EF.Functions.Like(a.Usuario.Nombre, $"%{texto}%"));
        }

        if (consulta.ValorDe("usuario") is string usuario)
            query = query.Where(a => a.Usuario != null && a.Usuario.Nombre == usuario);

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(a => a.Fecha >= desde);
        if (hasta is not null) query = query.Where(a => a.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "usuario" => desc ? query.OrderByDescending(a => a.Usuario!.Nombre).ThenByDescending(a => a.Id)
                              : query.OrderBy(a => a.Usuario!.Nombre).ThenBy(a => a.Id),
            _ => desc ? query.OrderByDescending(a => a.Fecha).ThenByDescending(a => a.Id)
                      : query.OrderBy(a => a.Fecha).ThenBy(a => a.Id),
        };

        return await query.PaginarAsync(consulta);
    }

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
