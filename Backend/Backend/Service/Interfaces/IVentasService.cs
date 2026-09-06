using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IVentasService
{
    // --- Pedidos ---
    Task<IEnumerable<PedidoResponse>> GetPedidosAsync(string? estado = null);
    Task<PedidoResponse> GetPedidoAsync(int id);

    /// <summary>Una página del listado de pedidos, resuelta en la base.</summary>
    Task<PaginaResponse<PedidoResponse>> ListarPedidosAsync(ConsultaTablaRequest consulta);

    /// <summary>Contadores del listado completo de pedidos.</summary>
    Task<ResumenPedidosResponse> GetResumenPedidosAsync();
    Task<PedidoResponse> CrearPedidoAsync(CrearPedidoRequest request, int? usuarioId);
    Task<PedidoResponse> ActualizarPedidoAsync(int id, CrearPedidoRequest request);

    /// <summary>Se despacha: el pedido se cierra y nace la NotaVenta, que descuenta el stock.</summary>
    Task<NotaVentaResponse> ConfirmarPedidoAsync(int id, ConfirmarPedidoRequest request, int? usuarioId);

    Task AnularPedidoAsync(int id);

    /// <summary>Qué cambió en este pedido y sus líneas, para verlo desde el propio documento.</summary>
    Task<IEnumerable<AuditoriaResponse>> GetHistorialPedidoAsync(int id);

    // --- Notas de venta ---
    Task<IEnumerable<NotaVentaResponse>> GetNotasVentaAsync(string? estado = null);
    Task<NotaVentaResponse> GetNotaVentaAsync(int id);

    /// <summary>Una página del listado de notas de venta.</summary>
    Task<PaginaResponse<NotaVentaResponse>> ListarNotasVentaAsync(ConsultaTablaRequest consulta);

    /// <summary>Contadores del listado completo de notas de venta.</summary>
    Task<ResumenNotasVentaResponse> GetResumenNotasVentaAsync();

    /// <summary>Venta directa, sin pedido previo: el stock sale al momento.</summary>
    Task<NotaVentaResponse> CrearNotaVentaAsync(CrearNotaVentaRequest request, int? usuarioId);

    /// <summary>
    /// Corrige una venta ya confirmada: el stock que había salido con las
    /// cantidades anteriores se devuelve y se vuelve a descontar con las
    /// nuevas. Una línea que se quita no se borra, queda Anulada.
    /// </summary>
    Task<NotaVentaResponse> ActualizarNotaVentaAsync(int id, CrearNotaVentaRequest request, int? usuarioId);

    Task AnularNotaVentaAsync(int id, int? usuarioId);

    /// <summary>Registra un abono contra el saldo pendiente de una nota de venta.</summary>
    Task<NotaVentaResponse> RegistrarPagoAsync(int id, PagoVentaRequest request, int? usuarioId);

    /// <summary>Corrige un pago ya registrado: método o monto.</summary>
    Task<NotaVentaResponse> ActualizarPagoAsync(int id, int pagoId, PagoVentaRequest request);

    /// <summary>Quita un pago registrado por error: su monto vuelve al saldo pendiente.</summary>
    Task<NotaVentaResponse> AnularPagoAsync(int id, int pagoId);

    /// <summary>Una página de las cuentas por cobrar, con el saldo resuelto en la base.</summary>
    Task<PaginaResponse<NotaVentaResponse>> ListarCuentasPorCobrarAsync(ConsultaTablaRequest consulta);

    /// <summary>Totales de todas las cuentas por cobrar.</summary>
    Task<ResumenCuentasResponse> GetResumenCuentasPorCobrarAsync();

    /// <summary>Notas de venta con saldo pendiente de cobro: base de "Cuentas por cobrar".</summary>
    Task<IEnumerable<NotaVentaResponse>> GetCuentasPorCobrarAsync();

    /// <summary>
    /// Los cobros que registró un usuario (el que hizo login si no se indica
    /// otro), de notas de venta vigentes — no las anuladas, esas revirtieron
    /// el cobro. Filtrable por rango de fechas.
    /// </summary>
    Task<IEnumerable<CobroResponse>> GetMisCobrosAsync(int? usuarioId, DateTime? desde, DateTime? hasta);

    /// <summary>Una página de los cobros del usuario, en el rango pedido.</summary>
    Task<PaginaResponse<CobroResponse>> ListarMisCobrosAsync(
        ConsultaTablaRequest consulta, int? usuarioId, DateTime? desde, DateTime? hasta);

    /// <summary>Totales de esos cobros, calculados sobre todo el rango.</summary>
    Task<ResumenCobrosResponse> GetResumenCobrosAsync(int? usuarioId, DateTime? desde, DateTime? hasta);

    /// <summary>Qué cambió en esta nota de venta: sobre todo anulaciones y movimientos de pago.</summary>
    Task<IEnumerable<AuditoriaResponse>> GetHistorialNotaVentaAsync(int id);
}
