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

    // --- Motivos ---
    Task<IEnumerable<MotivoResponse>> GetMotivosAsync();
    Task<MotivoResponse> CreateMotivoAsync(CreateMotivoRequest request);
    Task<MotivoResponse> UpdateMotivoAsync(int id, UpdateMotivoRequest request);
    Task DeleteMotivoAsync(int id);

    // --- Stock ---

    /// <summary>Stock de todos los productos, opcionalmente de un almacen.</summary>
    Task<IEnumerable<StockResponse>> GetStockAsync(int? almacenId);

    /// <summary>Stock y capas de un producto.</summary>
    Task<StockResponse> GetStockProductoAsync(int productoId, int? almacenId);

    // --- Kardex ---
    Task<IEnumerable<KardexResponse>> GetKardexAsync(
        int? productoId, int? almacenId, DateTime? desde, DateTime? hasta);

    // --- Ajustes ---
    Task<IEnumerable<DocumentoInventarioResponse>> GetDocumentosAsync();
    Task<DocumentoInventarioResponse> GetDocumentoAsync(int id);

    /// <summary>Registra el ajuste y mueve el stock. Todo o nada.</summary>
    Task<DocumentoInventarioResponse> CrearAjusteAsync(CrearAjusteRequest request, int? usuarioId);

    /// <summary>Crea el documento espejo que deshace otro.</summary>
    Task<DocumentoInventarioResponse> AnularAsync(int documentoId, int? usuarioId);
}
