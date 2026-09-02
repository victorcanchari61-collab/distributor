using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IInventarioService
{
    // --- Almacenes ---
    Task<IEnumerable<AlmacenResponse>> GetAlmacenesAsync();
    Task<AlmacenResponse> GetAlmacenAsync(int id);
    Task<AlmacenResponse> CreateAlmacenAsync(CreateAlmacenRequest request);
    Task<AlmacenResponse> UpdateAlmacenAsync(int id, UpdateAlmacenRequest request);
    Task DeleteAlmacenAsync(int id);

    // --- Stock y costos ---

    /// <summary>Stock, costos y capas de un producto.</summary>
    Task<StockProductoResponse> GetStockAsync(int productoId, int? almacenId = null);

    /// <summary>Entrada de mercaderia: crea una capa con su costo.</summary>
    Task<CapaCostoResponse> RegistrarEntradaAsync(EntradaRequest request);

    /// <summary>
    /// Salida de mercaderia: consume las capas mas antiguas y devuelve cuanto
    /// costo lo que salio.
    /// </summary>
    Task<CostoSalidaResponse> RegistrarSalidaAsync(SalidaRequest request);

    /// <summary>
    /// Cuanto costaria vender esa cantidad, sin tocar el stock. Sirve para
    /// mostrar el margen antes de confirmar un pedido.
    /// </summary>
    Task<CostoSalidaResponse> SimularSalidaAsync(SalidaRequest request);
}
