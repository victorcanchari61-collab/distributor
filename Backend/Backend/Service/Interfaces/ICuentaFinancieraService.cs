using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;

namespace Backend.Service.Interfaces;

/// <summary>
/// La Caja General y las cuentas bancarias — las entidades que sí tienen
/// saldo real. Ver docs/finanzas-tesoreria.md, sección 0.
/// </summary>
public interface ICuentaFinancieraService
{
    Task<IEnumerable<CuentaFinancieraResponse>> GetAllAsync();
    Task<CuentaFinancieraResponse> GetByIdAsync(int id);
    Task<CuentaFinancieraResponse> CreateAsync(CuentaFinancieraRequest request);
    Task<CuentaFinancieraResponse> UpdateAsync(int id, CuentaFinancieraRequest request);
    Task<IEnumerable<MovimientoCuentaResponse>> MovimientosAsync(int cuentaFinancieraId, DateTime? desde, DateTime? hasta);

    /// <summary>Para que otros servicios validen que la cuenta existe (y su naturaleza) antes de postear.</summary>
    Task<CuentaFinanciera> GetOrThrowAsync(int id);

    /// <summary>
    /// Postea un movimiento y actualiza el saldo de la cuenta. Lo llaman otros
    /// servicios (Arqueo, Gasto operativo...) — no se crea a mano desde una
    /// pantalla propia.
    /// </summary>
    Task<MovimientoCuenta> PostearAsync(
        int cuentaFinancieraId,
        string tipo,
        decimal monto,
        string documentoOrigen,
        int? origenId,
        int? usuarioId,
        DateTime? fecha = null,
        string? observacion = null);

    /// <summary>
    /// Reversa un movimiento anterior (al corregir o anular lo que lo generó):
    /// postea el espejo de signo contrario, mismo monto, misma cuenta.
    /// </summary>
    Task<MovimientoCuenta> ReversarAsync(int movimientoId, int? usuarioId);

    /// <summary>
    /// El saldo de la cuenta A UNA FECHA de corte (no el de hoy): el
    /// `SaldoResultante` del movimiento más reciente con Fecha ≤ esa. Para
    /// conciliación bancaria.
    /// </summary>
    Task<decimal> SaldoAFechaAsync(int cuentaFinancieraId, DateTime fecha);
}
