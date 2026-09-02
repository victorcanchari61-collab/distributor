using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IProductoService
{
    Task<IEnumerable<ProductoResponse>> GetAllAsync();
    Task<ProductoResponse> GetByIdAsync(int id);
    Task<ProductoResponse> CreateAsync(CreateProductoRequest request);
    Task<ProductoResponse> UpdateAsync(int id, UpdateProductoRequest request);
    Task<ProductoResponse> CambiarEstadoAsync(int id, bool activo);
    Task DeleteAsync(int id);

    // --- Presentaciones ---

    Task<PresentacionResponse> AgregarPresentacionAsync(int productoId, PresentacionRequest request);
    Task<PresentacionResponse> ActualizarPresentacionAsync(int id, PresentacionRequest request);
    Task EliminarPresentacionAsync(int id);

    /// <summary>
    /// Convierte una cantidad expresada en una presentacion a unidad base.
    /// Es lo que usaran compras, ventas e inventario para mover stock.
    /// </summary>
    Task<decimal> AUnidadBaseAsync(int presentacionId, decimal cantidad);
}
