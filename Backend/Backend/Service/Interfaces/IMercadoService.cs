using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IMercadoService
{
    Task<IEnumerable<MercadoResponse>> GetAllAsync();
    Task<MercadoResponse> GetByIdAsync(int id);
    Task<MercadoResponse> CreateAsync(CreateMercadoRequest request);
    Task<MercadoResponse> UpdateAsync(int id, UpdateMercadoRequest request);
    Task DeleteAsync(int id);
}
