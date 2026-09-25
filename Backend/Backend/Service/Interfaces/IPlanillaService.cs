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

    /// <summary>Arma la planilla de la semana, o la recalcula si está en borrador (conserva los ajustes a mano).</summary>
    Task<PlanillaResponse> GenerarAsync(DateTime semana, int? usuarioId);

    Task<PlanillaResponse> AjustarAsync(int detalleId, AjustePlanillaRequest request);

    Task<PlanillaResponse> PagarAsync(int id, PagarPlanillaRequest request, int? usuarioId);

    /// <summary>Si estaba pagada, reversa sus movimientos y los faltantes vuelven a quedar pendientes.</summary>
    Task<PlanillaResponse> AnularAsync(int id, int? usuarioId);

    /// <summary>Las cuentas activas de las que puede salir el pago.</summary>
    Task<IEnumerable<CuentaDestinoResponse>> CuentasAsync();
}
