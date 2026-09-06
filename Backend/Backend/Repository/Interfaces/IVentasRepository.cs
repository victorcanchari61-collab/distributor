using Backend.Models;
using Microsoft.EntityFrameworkCore.Storage;

namespace Backend.Repository.Interfaces;

public interface IVentasRepository
{
    Task<IDbContextTransaction> IniciarTransaccionAsync();
    Task GuardarAsync();

    // --- Pedidos ---
    Task<string> SiguienteNumeroPedidoAsync();
    Task<Pedido> AddPedidoAsync(Pedido pedido);
    Task<Pedido?> GetPedidoAsync(int id);
    Task<IEnumerable<Pedido>> GetPedidosAsync(string? estado = null);
    Task UpdatePedidoAsync(Pedido pedido);

    /// <summary>
    /// Reemplaza las líneas de un pedido Pendiente: se borran las actuales y
    /// se graban las nuevas, en una sola transacción.
    /// </summary>
    Task ReemplazarDetallePedidoAsync(int pedidoId, IEnumerable<PedidoDetalle> detalle);

    /// <summary>
    /// Cuánto está reservado por producto, sumando los pedidos Pendientes con
    /// reserva de stock activa — filtrado a un almacén si se indica. No hay
    /// una tabla de reservas aparte: se calcula de los pedidos vivos, así que
    /// confirmar o anular uno libera su reserva solo con dejar de cumplir el
    /// filtro.
    /// </summary>
    Task<Dictionary<int, decimal>> GetReservadoPorProductoAsync(int? almacenId);

    // --- Notas de venta ---
    Task<string> SiguienteNumeroNotaVentaAsync();
    Task<NotaVenta> AddNotaVentaAsync(NotaVenta notaVenta);
    Task<NotaVenta?> GetNotaVentaAsync(int id);
    Task<IEnumerable<NotaVenta>> GetNotasVentaAsync(string? estado = null);
    Task UpdateNotaVentaAsync(NotaVenta notaVenta);

    /// <summary>
    /// Una línea de nota de venta con su cabecera cargada, para poder marcar
    /// la venta completa como anulada al revertir su salida de stock.
    /// </summary>
    Task<NotaVentaDetalle?> GetNotaVentaDetalleConNotaVentaAsync(int id);

    /// <summary>
    /// Igual que <see cref="ReemplazarDetallePedidoAsync"/> pero para una nota
    /// de venta: diff línea por línea, nunca se borra, la que se quita queda
    /// Anulada.
    /// </summary>
    Task ReemplazarDetalleNotaVentaAsync(int notaVentaId, IEnumerable<NotaVentaDetalle> detalle);
}
