using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IProductoRepository
{
    /// <summary>Productos con categoria, marca, unidad y presentaciones.</summary>
    Task<IEnumerable<Producto>> GetAllConDetalleAsync();

    /// <summary>Una página del catálogo, buscada, filtrada y ordenada en la base.</summary>
    Task<(List<Producto> Items, int Total)> ListarAsync(ConsultaTablaRequest consulta);

    /// <summary>
    /// Una página de los productos que controlan stock, para la pantalla de
    /// Stock. Va aparte de <see cref="ListarAsync"/> porque esa incluye los
    /// que no manejan inventario.
    /// </summary>
    Task<(List<Producto> Items, int Total)> ListarConStockAsync(ConsultaTablaRequest consulta, int? almacenId);

    /// <summary>Contadores y valores de filtro del catálogo completo.</summary>
    Task<ResumenProductosResponse> ResumenAsync();

    Task<Producto?> GetConDetalleAsync(int id);

    Task<Producto?> GetByCodigoAsync(string codigo);

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
