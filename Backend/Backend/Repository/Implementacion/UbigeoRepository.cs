using Backend.Data;
using Backend.Models;
using Microsoft.EntityFrameworkCore;
using Backend.Repository.Interfaces;

namespace Backend.Repository.Implementacion;

public class UbigeoRepository : IUbigeoRepository
{
    private readonly AppDbContext _context;

    public UbigeoRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Departamento>> GetDepartamentosAsync() =>
        await _context.Departamentos.OrderBy(d => d.Nombre).ToListAsync();

    public async Task<IEnumerable<Provincia>> GetProvinciasAsync(int? departamentoId)
    {
        var query = _context.Provincias.AsQueryable();
        if (departamentoId is int id) query = query.Where(p => p.DepartamentoId == id);
        return await query.OrderBy(p => p.Nombre).ToListAsync();
    }

    public async Task<IEnumerable<Distrito>> GetDistritosAsync(int? provinciaId)
    {
        var query = _context.Distritos.Include(d => d.Provincia).AsQueryable();
        if (provinciaId is int id) query = query.Where(d => d.ProvinciaId == id);
        return await query.OrderBy(d => d.Nombre).ToListAsync();
    }

    public async Task<Distrito?> GetDistritoByIdAsync(int id) =>
        await _context.Distritos
            .Include(d => d.Provincia)
            .ThenInclude(p => p!.Departamento)
            .FirstOrDefaultAsync(d => d.Id == id);
}
