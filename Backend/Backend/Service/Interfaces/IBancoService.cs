using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>El catálogo de bancos (BBVA, BCP, Interbank...): de aquí cuelgan las cuentas bancarias.</summary>
public interface IBancoService
{
    Task<IEnumerable<BancoResponse>> GetAllAsync();
    Task<BancoResponse> CreateAsync(BancoRequest request);
    Task<BancoResponse> UpdateAsync(int id, BancoRequest request);
}
