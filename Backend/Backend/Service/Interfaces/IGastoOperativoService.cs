using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Ingresos y egresos que se registran a mano (no vienen de una venta ni de una
/// compra), clasificados por categoría en operativos y no operativos, con
/// plantillas recurrentes para lo mensual.
/// </summary>
public interface IGastoOperativoService
{
    // --- Categorías ---
    Task<IEnumerable<CategoriaMovimientoResponse>> GetCategoriasAsync();

    /// <summary>Las activas, opcionalmente de un tipo: para elegir al registrar un movimiento.</summary>
    Task<IEnumerable<CategoriaOpcionResponse>> GetCategoriasOpcionesAsync(string? tipo);

    Task<CategoriaMovimientoResponse> CrearCategoriaAsync(CategoriaMovimientoRequest request);
    Task<CategoriaMovimientoResponse> ActualizarCategoriaAsync(int id, CategoriaMovimientoRequest request);
    Task EliminarCategoriaAsync(int id);

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
