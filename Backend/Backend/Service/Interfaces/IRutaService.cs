using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IRutaService
{
    Task<IEnumerable<RutaResponse>> GetAllAsync();
    Task<RutaResponse> GetByIdAsync(int id);
    Task<RutaResponse> CreateAsync(CreateRutaRequest request);
    Task<RutaResponse> UpdateAsync(int id, UpdateRutaRequest request);
    Task DeleteAsync(int id);
}
