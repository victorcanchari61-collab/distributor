using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
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

    /// <summary>Una página del listado de pedidos, buscada, filtrada y ordenada en la base.</summary>
    Task<(List<Pedido> Items, int Total)> ListarPedidosAsync(ConsultaTablaRequest consulta);

    /// <summary>Contadores del listado completo de pedidos.</summary>
    Task<ResumenPedidosResponse> ResumenPedidosAsync();

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

    /// <summary>Una página del listado de notas de venta.</summary>
    Task<(List<NotaVenta> Items, int Total)> ListarNotasVentaAsync(ConsultaTablaRequest consulta);

    /// <summary>Contadores del listado completo de notas de venta.</summary>
    Task<ResumenNotasVentaResponse> ResumenNotasVentaAsync();

    /// <summary>
    /// Una página de los cobros de un usuario. Va directo contra los pagos y
    /// no recorriendo las notas de venta: antes se traían 300 notas enteras
    /// para quedarse con unos pocos pagos.
    /// </summary>
    Task<(List<PagoVenta> Items, int Total)> ListarCobrosAsync(
        ConsultaTablaRequest consulta, int? usuarioId, DateTime? desde, DateTime? hasta);

    /// <summary>Totales de esos cobros, sobre todo el rango y no sobre una página.</summary>
    Task<ResumenCobrosResponse> ResumenCobrosAsync(int? usuarioId, DateTime? desde, DateTime? hasta);

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
