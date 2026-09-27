using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Los cobros por Yape, Plin o transferencia se registran con su número de
/// operación y alguien los busca en el banco: los verifica o, si no aparecen,
/// los rechaza y se le descuentan a quien los cobró.
/// </summary>
public interface ICobroDigitalService
{
    /// <summary>Los cobros digitales del rango, más los pendientes de cualquier fecha.</summary>
    Task<IEnumerable<CobroDigitalResponse>> ListarAsync(DateTime desde, DateTime hasta);

    /// <summary>Los que cobró una persona en un periodo: entre un cierre y el siguiente.</summary>
    Task<List<CobroDigitalResponse>> DelPeriodoAsync(int usuarioId, DateTime? desdeExclusivo, DateTime hasta);

    /// <summary>Apareció en el banco por ese monto.</summary>
    Task<CobroDigitalResponse> VerificarAsync(int pagoId, int? usuarioId);

    /// <summary>Se verificó por error: vuelve a pendiente.</summary>
    Task<CobroDigitalResponse> QuitarVerificacionAsync(int pagoId);

    /// <summary>
    /// No apareció: se reversa su ingreso en el banco y el monto queda como
    /// faltante de quien lo cobró, para descontárselo en planilla.
    /// </summary>
    Task<CobroDigitalResponse> RechazarAsync(int pagoId, RechazarCobroRequest request, int? usuarioId);

    /// <summary>
    /// Falla si esa operación ya se cobró en otra venta vigente que entra a la
    /// misma cuenta: un mismo Yape no se registra dos veces.
    /// </summary>
    Task ExigirNumeroLibreAsync(int cuentaFinancieraId, string numeroOperacion, int? excluirPagoId);

    /// <summary>
    /// El cobro rechazado se anula (o su venta): lo que se le iba a descontar
    /// a quien lo cobró ya no va. No guarda: lo hace quien llama. Falla si ya
    /// se le descontó en una planilla pagada.
    /// </summary>
    Task LiberarDescuentoAsync(int pagoId);
}
