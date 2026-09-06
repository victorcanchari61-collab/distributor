using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IUbigeoService
{
    Task<IEnumerable<DepartamentoResponse>> GetDepartamentosAsync();
    Task<IEnumerable<ProvinciaResponse>> GetProvinciasAsync(int? departamentoId);
    Task<IEnumerable<DistritoResponse>> GetDistritosAsync(int? provinciaId);
}
