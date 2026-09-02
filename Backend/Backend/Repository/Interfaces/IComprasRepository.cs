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

    /// <summary>
    /// Una línea de compra con su cabecera y hermanas cargadas, para poder
    /// recalcular el estado de la compra completa (Pendiente / parcial /
    /// total) después de sumar o restar lo recibido.
    /// </summary>
    Task<CompraDetalle?> GetCompraDetalleConCompraAsync(int id);
}
