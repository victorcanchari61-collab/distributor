using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IListaPrecioService
{
    Task<IEnumerable<ListaPrecioResponse>> GetAllAsync();
    Task<ListaPrecioResponse> GetByIdAsync(int id);
    Task<ListaPrecioResponse> CreateAsync(CreateListaPrecioRequest request);
    Task<ListaPrecioResponse> UpdateAsync(int id, UpdateListaPrecioRequest request);
    Task<ListaPrecioResponse> MarcarPredeterminadaAsync(int id);
    Task DeleteAsync(int id);

    // --- Precios ---

    Task<IEnumerable<PrecioResponse>> GetPreciosAsync(int listaId);
    Task<IEnumerable<PrecioResponse>> GuardarPreciosAsync(int listaId, GuardarPreciosRequest request);
    Task EliminarPrecioAsync(int precioId);

    /// <summary>
    /// Precio que corresponde a una venta: el escalon mas alto cuya cantidad
    /// minima no supera lo pedido. Es lo que usara el pedido para tarifar.
    /// </summary>
    Task<PrecioResponse?> ResolverPrecioAsync(int listaId, int presentacionId, decimal cantidad);

    /// <summary>
    /// El precio que corresponde cobrar: el de la lista si lo tiene, y si no el de referencia del
    /// producto. <paramref name="listaId"/> en null o 0 es "sin lista": va directo a la referencia.
    /// </summary>
    Task<PrecioVentaResponse?> ResolverPrecioVentaAsync(int? listaId, int presentacionId, decimal cantidad);
}
