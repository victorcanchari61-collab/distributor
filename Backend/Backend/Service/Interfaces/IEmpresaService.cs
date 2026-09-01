using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IEmpresaService
{
    Task<IEnumerable<EmpresaResponse>> GetAllAsync();
    Task<EmpresaResponse> GetByIdAsync(int id);

    /// <summary>Empresa con la que opera el sistema.</summary>
    Task<EmpresaResponse> GetActivaAsync();

    Task<EmpresaResponse> CreateAsync(CreateEmpresaRequest request);
    Task<EmpresaResponse> UpdateAsync(int id, UpdateEmpresaRequest request);

    /// <summary>Activa una empresa y desactiva la que lo estuviera.</summary>
    Task<EmpresaResponse> ActivarAsync(int id);

    /// <summary>Habilita o retira una empresa sin eliminarla.</summary>
    Task<EmpresaResponse> CambiarHabilitacionAsync(int id, bool habilitada);

    Task DeleteAsync(int id);
}
