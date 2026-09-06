using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IFinanzasService
{
    // --- Métodos de pago ---
    Task<IEnumerable<MetodoPagoResponse>> GetMetodosPagoAsync();
    Task<MetodoPagoResponse> GetMetodoPagoAsync(int id);
    Task<MetodoPagoResponse> CreateMetodoPagoAsync(CreateMetodoPagoRequest request);
    Task<MetodoPagoResponse> UpdateMetodoPagoAsync(int id, UpdateMetodoPagoRequest request);
    Task DeleteMetodoPagoAsync(int id);

    // --- Arqueo de caja ---
    Task<ArqueoResumenResponse> GetResumenArqueoAsync(DateTime fecha);
    Task<IEnumerable<ArqueoCajaResponse>> GetHistorialArqueoAsync();

    /// <summary>Una página del historial de cierres de caja.</summary>
    Task<PaginaResponse<ArqueoCajaResponse>> ListarArqueosAsync(ConsultaTablaRequest consulta);
    Task<ArqueoCajaResponse> RegistrarArqueoAsync(RegistrarArqueoRequest request, int? usuarioId);
}
