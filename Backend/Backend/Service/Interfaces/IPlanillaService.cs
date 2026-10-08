using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// El pago semanal a los trabajadores: sueldo menos inasistencias, más
/// feriados trabajados, con bonos y descuentos a mano, y el descuento de sus
/// faltantes de caja pendientes.
/// </summary>
public interface IPlanillaService
{
    /// <summary>La planilla vigente de la semana que contiene esta fecha, o null si todavía no se armó.</summary>
    Task<PlanillaResponse?> GetSemanaAsync(DateTime semana);

    Task<IEnumerable<PlanillaResumenResponse>> HistorialAsync();

    Task<PlanillaResponse> GetAsync(int id);

    /// <summary>Arma la planilla de la semana, o la recalcula si está en borrador (conserva los ajustes a mano).</summary>
    Task<PlanillaResponse> GenerarAsync(DateTime semana, int? usuarioId);

    Task<PlanillaResponse> AjustarAsync(int detalleId, AjustePlanillaRequest request);

    Task<PlanillaResponse> PagarAsync(int id, PagarPlanillaRequest request, int? usuarioId);

    /// <summary>Si estaba pagada, reversa sus movimientos y los faltantes vuelven a quedar pendientes.</summary>
    Task<PlanillaResponse> AnularAsync(int id, int? usuarioId);

    /// <summary>Las cuentas activas de las que puede salir el pago.</summary>
    Task<IEnumerable<CuentaDestinoResponse>> CuentasAsync();

    /// <summary>
    /// Corre un cambio de asistencia o de feriados de esos días. Si su semana ya está pagada, lo
    /// rechaza; si está en borrador, la recalcula en la misma transacción.
    /// </summary>
    Task<T> CambiarDiasAsync<T>(IEnumerable<DateTime> dias, Func<Task<T>> cambio);

    /// <summary>
    /// Corre un cambio de adelantos (darlo, cambiar cómo se descuenta, anularlo) con los borradores
    /// bloqueados, y los recalcula en la misma transacción.
    /// </summary>
    Task<T> CambiarAdelantosAsync<T>(Func<Task<T>> cambio);
}
