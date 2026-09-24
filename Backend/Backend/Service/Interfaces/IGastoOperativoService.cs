using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Ingresos no ligados a venta (préstamos, aportes de capital) y egresos
/// operativos (planilla, alquiler, servicios), con plantillas recurrentes
/// para lo mensual. Ver docs/finanzas-tesoreria.md, sección 4.
/// </summary>
public interface IGastoOperativoService
{
    // --- Plantillas recurrentes ---
    Task<IEnumerable<GastoRecurrenteResponse>> GetRecurrentesAsync();
    Task<GastoRecurrenteResponse> CrearRecurrenteAsync(GastoRecurrenteRequest request);
    Task<GastoRecurrenteResponse> ActualizarRecurrenteAsync(int id, GastoRecurrenteRequest request);
    Task EliminarRecurrenteAsync(int id);

    /// <summary>Las plantillas activas que este mes todavía no tienen su pago registrado.</summary>
    Task<IEnumerable<GastoPendienteResponse>> GetPendientesAsync();

    // --- Movimientos (ingresos sueltos, egresos sueltos, o el pago de una plantilla) ---
    Task<IEnumerable<MovimientoOperativoResponse>> ListarAsync(DateTime desde, DateTime hasta);
    Task<MovimientoOperativoResponse> CrearAsync(MovimientoOperativoRequest request, int? usuarioId);
    Task<MovimientoOperativoResponse> AnularAsync(int id, int? usuarioId);
}
