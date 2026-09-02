using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IProductoRepository
{
    /// <summary>Productos con categoria, marca, unidad y presentaciones.</summary>
    Task<IEnumerable<Producto>> GetAllConDetalleAsync();

    Task<Producto?> GetConDetalleAsync(int id);

    Task<bool> ExisteCodigoAsync(string codigo, int? excepto = null);

    Task<Producto> AddAsync(Producto producto);
    Task UpdateAsync(Producto producto);
    Task DeleteAsync(Producto producto);

    // --- Presentaciones ---

    Task<ProductoPresentacion?> GetPresentacionAsync(int id);
    Task<ProductoPresentacion> AddPresentacionAsync(ProductoPresentacion presentacion);
    Task UpdatePresentacionAsync(ProductoPresentacion presentacion);
    Task DeletePresentacionAsync(ProductoPresentacion presentacion);

    /// <summary>Cuantos precios cuelgan de una presentacion.</summary>
    Task<int> ContarPreciosAsync(int presentacionId);

    /// <summary>
    /// Quita la marca de predeterminada al resto de presentaciones del
    /// producto: solo una puede serlo por operacion.
    /// </summary>
    Task LimpiarPredeterminadaAsync(int productoId, int exceptoId, bool venta);
}
