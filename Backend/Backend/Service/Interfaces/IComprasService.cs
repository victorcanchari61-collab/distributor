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

    /// <summary>Registra un abono contra el saldo pendiente de una compra.</summary>
    Task<CompraResponse> RegistrarPagoAsync(int id, PagoCompraRequest request, int? usuarioId);

    /// <summary>Corrige un pago ya registrado: método o monto.</summary>
    Task<CompraResponse> ActualizarPagoAsync(int id, int pagoId, PagoCompraRequest request);

    /// <summary>Quita un pago registrado por error: su monto vuelve al saldo pendiente.</summary>
    Task<CompraResponse> AnularPagoAsync(int id, int pagoId);

    /// <summary>Compras con saldo pendiente de pago: base de "Cuentas por pagar".</summary>
    Task<IEnumerable<CompraResponse>> GetCuentasPorPagarAsync();
}
