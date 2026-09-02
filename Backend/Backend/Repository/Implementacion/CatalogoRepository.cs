using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class CatalogoRepository : ICatalogoRepository
{
    private readonly AppDbContext _context;

    public CatalogoRepository(AppDbContext context)
    {
        _context = context;
    }

    // --- Categorias ---

    public async Task<IEnumerable<Categoria>> GetCategoriasAsync()
    {
        // Activas primero, igual que en clientes y proveedores: las inactivas
        // siguen listandose para poder reactivarlas.
        return await _context.Categorias
            .OrderByDescending(c => c.Activo)
            .ThenBy(c => c.Nombre)
            .ToListAsync();
    }

    public async Task<Categoria?> GetCategoriaAsync(int id) =>
        await _context.Categorias.FirstOrDefaultAsync(c => c.Id == id);

    public async Task<bool> ExisteCategoriaAsync(string nombre, int? excepto = null) =>
        await _context.Categorias.AnyAsync(c =>
            c.Nombre == nombre && (excepto == null || c.Id != excepto));

    public async Task<int> ContarProductosPorCategoriaAsync(int id) =>
        await _context.Productos.CountAsync(p => p.CategoriaId == id);

    public async Task<Categoria> AddCategoriaAsync(Categoria categoria)
    {
        await _context.Categorias.AddAsync(categoria);
        await _context.SaveChangesAsync();
        return categoria;
    }

    public async Task UpdateCategoriaAsync(Categoria categoria)
    {
        _context.Categorias.Update(categoria);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteCategoriaAsync(Categoria categoria)
    {
        _context.Categorias.Remove(categoria);
        await _context.SaveChangesAsync();
    }

    // --- Marcas ---

    public async Task<IEnumerable<Marca>> GetMarcasAsync()
    {
        return await _context.Marcas
            .OrderByDescending(m => m.Activo)
            .ThenBy(m => m.Nombre)
            .ToListAsync();
    }

    public async Task<Marca?> GetMarcaAsync(int id) =>
        await _context.Marcas.FirstOrDefaultAsync(m => m.Id == id);

    public async Task<bool> ExisteMarcaAsync(string nombre, int? excepto = null) =>
        await _context.Marcas.AnyAsync(m =>
            m.Nombre == nombre && (excepto == null || m.Id != excepto));

    public async Task<int> ContarProductosPorMarcaAsync(int id) =>
        await _context.Productos.CountAsync(p => p.MarcaId == id);

    public async Task<Marca> AddMarcaAsync(Marca marca)
    {
        await _context.Marcas.AddAsync(marca);
        await _context.SaveChangesAsync();
        return marca;
    }

    public async Task UpdateMarcaAsync(Marca marca)
    {
        _context.Marcas.Update(marca);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteMarcaAsync(Marca marca)
    {
        _context.Marcas.Remove(marca);
        await _context.SaveChangesAsync();
    }

    // --- Unidades de medida ---

    public async Task<IEnumerable<UnidadMedida>> GetUnidadesAsync()
    {
        return await _context.UnidadesMedida
            .OrderByDescending(u => u.Activo)
            .ThenBy(u => u.Tipo)
            .ThenBy(u => u.Codigo)
            .ToListAsync();
    }

    public async Task<UnidadMedida?> GetUnidadAsync(int id) =>
        await _context.UnidadesMedida.FirstOrDefaultAsync(u => u.Id == id);

    public async Task<bool> ExisteUnidadAsync(string codigo, int? excepto = null) =>
        await _context.UnidadesMedida.AnyAsync(u =>
            u.Codigo == codigo && (excepto == null || u.Id != excepto));

    public async Task<int> ContarUsosUnidadAsync(int id)
    {
        // Una unidad se usa como base del producto, como unidad del contenido
        // envasado o dentro de una presentacion. Cualquiera de los tres impide
        // borrarla.
        var comoBase = await _context.Productos.CountAsync(p => p.UnidadBaseId == id);
        var comoContenido = await _context.Productos.CountAsync(p => p.ContenidoUnidadId == id);
        var enPresentaciones = await _context.Presentaciones.CountAsync(p => p.UnidadId == id);

        return comoBase + comoContenido + enPresentaciones;
    }

    public async Task<UnidadMedida> AddUnidadAsync(UnidadMedida unidad)
    {
        await _context.UnidadesMedida.AddAsync(unidad);
        await _context.SaveChangesAsync();
        return unidad;
    }

    public async Task UpdateUnidadAsync(UnidadMedida unidad)
    {
        _context.UnidadesMedida.Update(unidad);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteUnidadAsync(UnidadMedida unidad)
    {
        _context.UnidadesMedida.Remove(unidad);
        await _context.SaveChangesAsync();
    }
}
