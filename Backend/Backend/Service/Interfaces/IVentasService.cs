using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IVentasService
{
    // --- Pedidos ---
    Task<IEnumerable<PedidoResponse>> GetPedidosAsync(string? estado = null);
    Task<PedidoResponse> GetPedidoAsync(int id);
    Task<PedidoResponse> CrearPedidoAsync(CrearPedidoRequest request, int? usuarioId);
    Task<PedidoResponse> ActualizarPedidoAsync(int id, CrearPedidoRequest request);

    /// <summary>Se despacha: el pedido se cierra y nace la NotaVenta, que descuenta el stock.</summary>
    Task<NotaVentaResponse> ConfirmarPedidoAsync(int id, ConfirmarPedidoRequest request, int? usuarioId);

    Task AnularPedidoAsync(int id);

    // --- Notas de venta ---
    Task<IEnumerable<NotaVentaResponse>> GetNotasVentaAsync(string? estado = null);
    Task<NotaVentaResponse> GetNotaVentaAsync(int id);

    /// <summary>Venta directa, sin pedido previo: el stock sale al momento.</summary>
    Task<NotaVentaResponse> CrearNotaVentaAsync(CrearNotaVentaRequest request, int? usuarioId);

    Task AnularNotaVentaAsync(int id, int? usuarioId);
}
