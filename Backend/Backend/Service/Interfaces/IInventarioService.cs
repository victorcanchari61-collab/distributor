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

    /// <summary>Documentos de una familia (AJUSTE, TRANSFERENCIA...) y sus anulaciones.</summary>
    Task<IEnumerable<DocumentoInventarioResponse>> GetDocumentosAsync(string? familia = null);

    Task<DocumentoInventarioResponse> GetDocumentoAsync(int id);

    /// <summary>Registra el ajuste y mueve el stock. Todo o nada.</summary>
    Task<DocumentoInventarioResponse> CrearAjusteAsync(CrearAjusteRequest request, int? usuarioId);

    /// <summary>Crea el documento espejo que deshace otro.</summary>
    Task<DocumentoInventarioResponse> AnularAsync(int documentoId, int? usuarioId);

    // --- Transferencias ---

    /// <summary>
    /// Mueve mercadería de un almacén propio a otro. El costo viaja con ella:
    /// no se vuelve a declarar, es el mismo con el que estaba en origen.
    /// </summary>
    Task<DocumentoInventarioResponse> CrearTransferenciaAsync(
        CrearTransferenciaRequest request, int? usuarioId);

    // --- Prestamos ---

    Task<IEnumerable<PrestamoResponse>> GetPrestamosAsync();
    Task<PrestamoResponse> GetPrestamoAsync(int id);

    /// <summary>Registra el préstamo y mueve el stock: sale o entra, según el tipo.</summary>
    Task<PrestamoResponse> CrearPrestamoAsync(CrearPrestamoRequest request, int? usuarioId);

    /// <summary>
    /// Devuelve, total o parcialmente. Si es lo que presté, vuelve a mis
    /// capas al costo con que salió; si es lo que me prestaron, sale de la
    /// capa que esa mercadería creó al entrar.
    /// </summary>
    Task<PrestamoResponse> DevolverPrestamoAsync(
        int prestamoId, DevolverPrestamoRequest request, int? usuarioId);

    // --- Recepciones ---

    /// <summary>
    /// Registra que llegó mercadería de una Compra, total o parcialmente, y la
    /// mete al stock con motivo del sistema "Compra": crea una capa de costo
    /// por línea, al costo pactado en la compra.
    /// </summary>
    Task<DocumentoInventarioResponse> CrearRecepcionAsync(
        CrearRecepcionRequest request, int? usuarioId);
}
