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
