using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>Los préstamos que recibe el negocio: la plata que entra y la deuda que queda hasta pagarla.</summary>
public interface IFinanciamientoService
{
    Task<IEnumerable<FinanciamientoResponse>> ListarAsync();
    Task<FinanciamientoResponse> GetAsync(int id);
    Task<FinanciamientoResponse> CrearAsync(CrearFinanciamientoRequest request, int? usuarioId);
    Task<FinanciamientoResponse> RegistrarPagoAsync(int id, PagoFinanciamientoRequest request, int? usuarioId);
    Task<FinanciamientoResponse> AnularPagoAsync(int id, int pagoId, int? usuarioId);

    /// <summary>Solo sin pagos vigentes: reversa el ingreso del préstamo.</summary>
    Task<FinanciamientoResponse> AnularAsync(int id, int? usuarioId);

    /// <summary>Las cuentas activas, para elegir a dónde entra o de dónde sale.</summary>
    Task<IEnumerable<CuentaDestinoResponse>> CuentasAsync();
}
