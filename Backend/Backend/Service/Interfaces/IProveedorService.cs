using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IProveedorService
{
    Task<IEnumerable<ProveedorResponse>> GetAllAsync();
    Task<ProveedorResponse> GetByIdAsync(int id);
    Task<ProveedorResponse> CreateAsync(CreateProveedorRequest request);
    Task<ProveedorResponse> UpdateAsync(int id, UpdateProveedorRequest request);
    Task DeleteAsync(int id);
}
