using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IRolService
{
    Task<IEnumerable<RolResponse>> GetAllAsync();
    Task<RolResponse> GetByIdAsync(int id);
    Task<RolResponse> CreateAsync(CreateRolRequest request);
    Task<RolResponse> UpdateAsync(int id, UpdateRolRequest request);

    /// <summary>Guarda la matriz de accesos del rol.</summary>
    Task<RolResponse> UpdatePermisosAsync(int id, UpdatePermisosRequest request);

    Task DeleteAsync(int id);
}
