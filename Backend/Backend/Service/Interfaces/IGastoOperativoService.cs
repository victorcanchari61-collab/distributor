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

    /// <summary>Las activas que no son del sistema, opcionalmente de un tipo: para elegir al registrar un movimiento a mano.</summary>
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
    /// <param name="delSistema">
    /// True solo cuando lo registra otro módulo (la planilla): es lo único que
    /// puede usar una categoría del sistema, y anular lo que esta generó.
    /// </param>
    Task<MovimientoOperativoResponse> CrearAsync(MovimientoOperativoRequest request, int? usuarioId, bool delSistema = false);
    Task<MovimientoOperativoResponse> AnularAsync(int id, int? usuarioId, bool delSistema = false);
}
