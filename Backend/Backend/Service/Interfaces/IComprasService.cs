using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IComprasService
{
    // --- Ordenes de compra ---
    Task<IEnumerable<OrdenCompraResponse>> GetOrdenesAsync(string? estado = null);
    Task<OrdenCompraResponse> GetOrdenAsync(int id);
    Task<OrdenCompraResponse> CrearOrdenAsync(CrearOrdenCompraRequest request, int? usuarioId);
    Task<OrdenCompraResponse> ActualizarOrdenAsync(int id, CrearOrdenCompraRequest request);

    /// <summary>El proveedor aceptó despachar: la orden se cierra y nace la Compra.</summary>
    Task<OrdenCompraResponse> ConfirmarOrdenAsync(int id);

    Task AnularOrdenAsync(int id);

    // --- Compras ---
    Task<IEnumerable<CompraResponse>> GetComprasAsync(string? estado = null);
    Task<CompraResponse> GetCompraAsync(int id);

    /// <summary>Compra directa, sin orden previa: al contado, en el momento.</summary>
    Task<CompraResponse> CrearCompraAsync(CrearCompraRequest request, int? usuarioId);

    /// <summary>Solo si nada se ha recibido: si ya hay recepciones, ya no se edita.</summary>
    Task<CompraResponse> ActualizarCompraAsync(int id, CrearCompraRequest request);

    Task AnularCompraAsync(int id);
}
