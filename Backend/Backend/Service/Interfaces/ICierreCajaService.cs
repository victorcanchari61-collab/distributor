using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>El cierre de la caja propia de un vendedor o repartidor, desde Mi Caja.</summary>
public interface ICierreCajaService
{
    /// <summary>Las cuentas activas a las que puede entregar lo contado: todas menos su propia caja.</summary>
    Task<IEnumerable<CuentaDestinoResponse>> DestinosAsync(int usuarioId);

    Task<CierreCajaResponse> CerrarAsync(int usuarioId, CerrarCajaRequest request);
}
