using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>Los días no laborables o de pago especial, registrados a mano. Ver <see cref="Models.Feriado"/>.</summary>
public interface IFeriadoService
{
    Task<IEnumerable<FeriadoResponse>> GetAllAsync();
    Task<FeriadoResponse> CreateAsync(FeriadoRequest request);
    Task<FeriadoResponse> UpdateAsync(int id, FeriadoRequest request);
    Task DeleteAsync(int id);
}
