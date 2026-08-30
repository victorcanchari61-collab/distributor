using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IClienteService
{
    Task<IEnumerable<ClienteResponse>> GetAllAsync();
    Task<ClienteResponse> GetByIdAsync(int id);
    Task<ClienteResponse> CreateAsync(CreateClienteRequest request);
    Task<ClienteResponse> UpdateAsync(int id, UpdateClienteRequest request);
    Task DeleteAsync(int id);
}
