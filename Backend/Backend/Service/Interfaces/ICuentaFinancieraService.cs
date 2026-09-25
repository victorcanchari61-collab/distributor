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
    Task<CuentaFinancieraResponse> CreateAsync(CuentaFinancieraRequest request, int? usuarioId = null);
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

    /// <summary>
    /// La Caja de este usuario (un vendedor/repartidor), si tiene una
    /// asignada — null si no. Ya no se crea sola: la asigna un administrador
    /// desde Finanzas &gt; Cajas. Ver docs/finanzas-tesoreria.md, "Mi Caja".
    /// </summary>
    Task<CuentaFinanciera?> ObtenerCajaUsuarioAsync(int usuarioId);

    /// <summary>Igual que <see cref="ObtenerCajaUsuarioAsync"/>, pero exige que exista.</summary>
    Task<CuentaFinanciera> ExigirCajaUsuarioAsync(int usuarioId);

    /// <summary>
    /// Mueve plata de una cuenta a otra: un Egreso en origen y un Ingreso en
    /// destino, mismo documento y mismo momento. Se usa para fondear una Caja
    /// desde la Caja General, y para liquidar una Caja hacia la Caja General.
    /// </summary>
    Task<(MovimientoCuenta Salida, MovimientoCuenta Entrada)> TransferirAsync(
        int cuentaOrigenId,
        int cuentaDestinoId,
        decimal monto,
        string documentoOrigen,
        int? origenId,
        int? usuarioId,
        DateTime? fecha = null,
        string? observacion = null);

    /// <summary>Reversa las dos mitades de una transferencia hecha con <see cref="TransferirAsync"/>.</summary>
    Task ReversarTransferenciaAsync(int movimientoSalidaId, int movimientoEntradaId, int? usuarioId);
}
