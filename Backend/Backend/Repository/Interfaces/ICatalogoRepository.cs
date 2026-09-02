using Backend.Models;

namespace Backend.Repository.Interfaces;

/// <summary>
/// Categorias, marcas y unidades de medida.
///
/// Van juntas porque son las tres tablas de apoyo del producto: se consultan
/// siempre para lo mismo (existe el nombre, esta en uso) y separarlas serian
/// tres repositorios de cuatro lineas cada uno.
/// </summary>
public interface ICatalogoRepository
{
    // --- Categorias ---
    Task<IEnumerable<Categoria>> GetCategoriasAsync();
    Task<Categoria?> GetCategoriaAsync(int id);
    Task<bool> ExisteCategoriaAsync(string nombre, int? excepto = null);
    Task<int> ContarProductosPorCategoriaAsync(int id);
    Task<Categoria> AddCategoriaAsync(Categoria categoria);
    Task UpdateCategoriaAsync(Categoria categoria);
    Task DeleteCategoriaAsync(Categoria categoria);

    // --- Marcas ---
    Task<IEnumerable<Marca>> GetMarcasAsync();
    Task<Marca?> GetMarcaAsync(int id);
    Task<bool> ExisteMarcaAsync(string nombre, int? excepto = null);
    Task<int> ContarProductosPorMarcaAsync(int id);
    Task<Marca> AddMarcaAsync(Marca marca);
    Task UpdateMarcaAsync(Marca marca);
    Task DeleteMarcaAsync(Marca marca);

    // --- Unidades de medida ---
    Task<IEnumerable<UnidadMedida>> GetUnidadesAsync();
    Task<UnidadMedida?> GetUnidadAsync(int id);
    Task<bool> ExisteUnidadAsync(string codigo, int? excepto = null);

    /// <summary>Productos y presentaciones que la usan.</summary>
    Task<int> ContarUsosUnidadAsync(int id);

    Task<UnidadMedida> AddUnidadAsync(UnidadMedida unidad);
    Task UpdateUnidadAsync(UnidadMedida unidad);
    Task DeleteUnidadAsync(UnidadMedida unidad);
}
