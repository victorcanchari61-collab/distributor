using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Compara el saldo contable de una cuenta bancaria, a una fecha de corte,
/// contra el extracto real. Ver docs/finanzas-tesoreria.md, sección 2.
/// </summary>
public interface IConciliacionBancariaService
{
    Task<IEnumerable<ConciliacionBancariaResponse>> ListarAsync(int cuentaFinancieraId);
    Task<ConciliacionBancariaResponse> CrearAsync(ConciliacionBancariaRequest request, int? usuarioId);
    Task<ConciliacionBancariaResponse> MarcarConciliadaAsync(int id);
}
