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
}
