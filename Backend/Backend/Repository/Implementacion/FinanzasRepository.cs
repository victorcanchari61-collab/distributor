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
        await _context.Compras.CountAsync(c => c.MetodoPagoId == metodoPagoId);
}
