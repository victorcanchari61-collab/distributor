using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class ListaPrecioRepository : IListaPrecioRepository
{
    private readonly AppDbContext _context;

    public ListaPrecioRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<ListaPrecio>> GetAllAsync()
    {
        return await _context.ListasPrecio
            .OrderByDescending(l => l.Activo)
            .ThenByDescending(l => l.EsPredeterminada)
            .ThenBy(l => l.Nombre)
            .ToListAsync();
    }

    public async Task<ListaPrecio?> GetAsync(int id) =>
        await _context.ListasPrecio.FirstOrDefaultAsync(l => l.Id == id);

    public async Task<bool> ExisteNombreAsync(string nombre, int? excepto = null) =>
        await _context.ListasPrecio.AnyAsync(l =>
            l.Nombre == nombre && (excepto == null || l.Id != excepto));

    public async Task<int> ContarPreciosAsync(int listaId) =>
        await _context.Precios.CountAsync(p => p.ListaPrecioId == listaId);

    public async Task<ListaPrecio> AddAsync(ListaPrecio lista)
    {
        await _context.ListasPrecio.AddAsync(lista);
        await _context.SaveChangesAsync();
        return lista;
    }

    public async Task UpdateAsync(ListaPrecio lista)
    {
        _context.ListasPrecio.Update(lista);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(ListaPrecio lista)
    {
        _context.ListasPrecio.Remove(lista);
        await _context.SaveChangesAsync();
    }

    public async Task MarcarPredeterminadaAsync(int id)
    {
        var listas = await _context.ListasPrecio.ToListAsync();

        foreach (var lista in listas)
        {
            lista.EsPredeterminada = lista.Id == id;
        }

        await _context.SaveChangesAsync();
    }

    // --- Precios ---

    public async Task<IEnumerable<PrecioProducto>> GetPreciosAsync(int listaId)
    {
        return await _context.Precios
            .Include(p => p.ListaPrecio)
            .Include(p => p.Presentacion)
            .ThenInclude(pr => pr!.Producto)
            .ThenInclude(pro => pro!.UnidadBase)
            .Where(p => p.ListaPrecioId == listaId)
            .OrderBy(p => p.Presentacion!.Producto!.Nombre)
            .ThenBy(p => p.Presentacion!.Factor)
            .ThenBy(p => p.CantidadMinima)
            .ToListAsync();
    }

    public async Task<PrecioProducto?> GetPrecioAsync(int id) =>
        await _context.Precios
            .Include(p => p.ListaPrecio)
            .Include(p => p.Presentacion)
            .ThenInclude(pr => pr!.Producto)
            .ThenInclude(pro => pro!.UnidadBase)
            .FirstOrDefaultAsync(p => p.Id == id);

    public async Task<PrecioProducto?> BuscarPrecioAsync(
        int listaId, int presentacionId, decimal cantidadMinima)
    {
        return await _context.Precios.FirstOrDefaultAsync(p =>
            p.ListaPrecioId == listaId
            && p.PresentacionId == presentacionId
            && p.CantidadMinima == cantidadMinima);
    }

    public async Task<PrecioProducto> AddPrecioAsync(PrecioProducto precio)
    {
        await _context.Precios.AddAsync(precio);
        await _context.SaveChangesAsync();
        return precio;
    }

    public async Task UpdatePrecioAsync(PrecioProducto precio)
    {
        _context.Precios.Update(precio);
        await _context.SaveChangesAsync();
    }

    public async Task DeletePrecioAsync(PrecioProducto precio)
    {
        _context.Precios.Remove(precio);
        await _context.SaveChangesAsync();
    }

    public Task GuardarCambiosAsync() => _context.SaveChangesAsync();
}
