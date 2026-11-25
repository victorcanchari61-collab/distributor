using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Lo que se le devuelve a un proveedor de una compra (llegó mal o no llegó), y el saldo a favor que eso deja cuando ya
/// se le había pagado.
/// </summary>
public interface IDevolucionProveedorService
{
    /// <summary>Las devoluciones, las más nuevas primero; de una compra si se indica.</summary>
    Task<IEnumerable<DevolucionProveedorResponse>> GetAllAsync(int? compraId);

    Task<DevolucionProveedorResponse> GetAsync(int id);

    /// <summary>
    /// Registra la devolución. Lo que había llegado sale del stock. Lo que se repone vuelve a quedar por recibir en
    /// la compra; lo que se descuenta baja la compra: primero lo que se debe y, si ya estaba pagado, el resto queda
    /// como saldo a favor con el proveedor.
    /// </summary>
    Task<DevolucionProveedorResponse> CrearAsync(CrearDevolucionProveedorRequest request, int? usuarioId);

    /// <summary>
    /// La deshace: el stock vuelve, la compra queda como estaba y el saldo a favor que dio se retira. No se puede si
    /// ya se recibió la reposición o si ya se cobró o usó ese saldo.
    /// </summary>
    Task<DevolucionProveedorResponse> AnularAsync(int id, int? usuarioId);

    // --- Saldo a favor ---

    /// <summary>Los proveedores que deben devolver plata, con cuánto.</summary>
    Task<IEnumerable<SaldoFavorProveedorResponse>> GetSaldosAsync();

    Task<decimal> GetSaldoAsync(int proveedorId);

    Task<IEnumerable<MovimientoSaldoProveedorResponse>> GetMovimientosSaldoAsync(int proveedorId);

    /// <summary>El proveedor devolvió plata del saldo a favor: entra a una caja o banco.</summary>
    Task<MovimientoSaldoProveedorResponse> CobrarSaldoAsync(
        int proveedorId, CobrarSaldoProveedorRequest request, int? usuarioId);

    /// <summary>Un cobro registrado por error: la plata sale de la cuenta y vuelve al saldo a favor.</summary>
    Task AnularCobroAsync(int movimientoId, int? usuarioId);

    /// <summary>Usa el saldo a favor para pagar otra compra del mismo proveedor: un pago que no mueve plata.</summary>
    Task<CompraResponse> AplicarSaldoAsync(int compraId, AplicarSaldoProveedorRequest request, int? usuarioId);
}
