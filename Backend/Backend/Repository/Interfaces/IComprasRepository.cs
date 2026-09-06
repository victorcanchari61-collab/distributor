using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Microsoft.EntityFrameworkCore.Storage;

namespace Backend.Repository.Interfaces;

public interface IComprasRepository
{
    Task<IDbContextTransaction> IniciarTransaccionAsync();
    Task GuardarAsync();

    // --- Ordenes de compra ---
    Task<string> SiguienteNumeroOrdenAsync();
    Task<OrdenCompra> AddOrdenAsync(OrdenCompra orden);
    Task<OrdenCompra?> GetOrdenAsync(int id);
    Task<IEnumerable<OrdenCompra>> GetOrdenesAsync(string? estado = null);
    Task UpdateOrdenAsync(OrdenCompra orden);

    /// <summary>Una página del listado de órdenes de compra.</summary>
    Task<(List<OrdenCompra> Items, int Total)> ListarOrdenesAsync(ConsultaTablaRequest consulta);

    /// <summary>Contadores del listado completo de órdenes.</summary>
    Task<ResumenOrdenesCompraResponse> ResumenOrdenesAsync();

    /// <summary>
    /// Reemplaza las líneas de una orden Pendiente: se borran las actuales y
    /// se graban las nuevas, en una sola transacción.
    /// </summary>
    Task ReemplazarDetalleOrdenAsync(int ordenId, IEnumerable<OrdenCompraDetalle> detalle);

    // --- Compras ---
    Task<string> SiguienteNumeroCompraAsync();
    Task<Compra> AddCompraAsync(Compra compra);
    Task<Compra?> GetCompraAsync(int id);
    Task<IEnumerable<Compra>> GetComprasAsync(string? estado = null);
    Task UpdateCompraAsync(Compra compra);

    /// <summary>Una página del listado de compras.</summary>
    Task<(List<Compra> Items, int Total)> ListarComprasAsync(ConsultaTablaRequest consulta);

    /// <summary>Contadores del listado completo de compras.</summary>
    Task<ResumenComprasResponse> ResumenComprasAsync();

    /// <summary>
    /// Las compras que todavía esperan mercadería. Va sin paginar a propósito:
    /// alimenta el selector del modal de recepción, que necesita verlas todas,
    /// y por definición son pocas — una compra deja la lista al recibirse.
    /// </summary>
    Task<List<Compra>> GetComprasAbiertasAsync();

    /// <summary>
    /// Una línea de compra con su cabecera y hermanas cargadas, para poder
    /// recalcular el estado de la compra completa (Pendiente / parcial /
    /// total) después de sumar o restar lo recibido.
    /// </summary>
    Task<CompraDetalle?> GetCompraDetalleConCompraAsync(int id);

    /// <summary>
    /// Reemplaza las líneas de una compra Pendiente (nada recibido aún): se
    /// borran las actuales y se graban las nuevas, en una sola transacción.
    /// </summary>
    Task ReemplazarDetalleCompraAsync(int compraId, IEnumerable<CompraDetalle> detalle);

    /// <summary>Reemplaza los pagos de una compra Pendiente, igual que sus líneas.</summary>
    Task ReemplazarPagosCompraAsync(int compraId, IEnumerable<CompraPago> pagos);
}
