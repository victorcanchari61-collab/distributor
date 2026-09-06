using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IProductoService
{
    /// <summary>
    /// Todo el catálogo, sin paginar. Lo usan los buscadores de producto de
    /// otras pantallas, que filtran en memoria mientras se escribe.
    /// </summary>
    Task<IEnumerable<ProductoResponse>> GetAllAsync();

    /// <summary>Una página del catálogo, resuelta en la base.</summary>
    Task<PaginaResponse<ProductoResponse>> ListarAsync(ConsultaTablaRequest consulta);

    /// <summary>Contadores y valores de filtro del catálogo completo.</summary>
    Task<ResumenProductosResponse> GetResumenAsync();
    Task<ProductoResponse> GetByIdAsync(int id);
    Task<ProductoResponse> CreateAsync(CreateProductoRequest request);
    Task<ProductoResponse> UpdateAsync(int id, UpdateProductoRequest request);
    Task<ProductoResponse> CambiarEstadoAsync(int id, bool activo);
    Task DeleteAsync(int id);

    /// <summary>
    /// Alta masiva desde un catálogo externo: crea el producto, sus
    /// presentaciones y hasta tres precios (contado, por saco, mayorista).
    /// </summary>
    Task<ImportarResponse> ImportarAsync(ImportarProductosRequest request);

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
