using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>El cierre de la caja propia de un vendedor o repartidor, y su gestión desde Finanzas.</summary>
public interface ICierreCajaService
{
    /// <summary>Las cuentas activas a las que puede entregar lo contado: todas menos su propia caja.</summary>
    Task<IEnumerable<CuentaDestinoResponse>> DestinosAsync(int usuarioId);

    Task<CierreCajaResponse> CerrarAsync(int usuarioId, CerrarCajaRequest request);

    /// <summary>Todos los cierres del rango, de todas las cajas, con el estado de su descuento.</summary>
    Task<IEnumerable<CierreCajaResponse>> ListarAsync(DateTime desde, DateTime hasta);

    /// <summary>
    /// Deshace un cierre mal contado: reversa la entrega y el ajuste y anula su
    /// descuento. No se puede si ese descuento ya entró en una planilla pagada.
    /// </summary>
    Task<CierreCajaResponse> AnularAsync(int id, int? usuarioId);
}
