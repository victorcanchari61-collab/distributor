using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Los vehículos de reparto, sus tipos y quienes los conducen.
/// </summary>
public interface IFlotaService
{
    // --- Tipos de vehículo ---
    Task<IEnumerable<TipoVehiculoResponse>> GetTiposAsync();
    Task<TipoVehiculoResponse> GetTipoAsync(int id);
    Task<TipoVehiculoResponse> CrearTipoAsync(TipoVehiculoRequest request);
    Task<TipoVehiculoResponse> ActualizarTipoAsync(int id, TipoVehiculoRequest request);
    Task EliminarTipoAsync(int id);

    // --- Vehículos ---
    Task<IEnumerable<VehiculoResponse>> GetVehiculosAsync();
    Task<VehiculoResponse> GetVehiculoAsync(int id);
    Task<VehiculoResponse> CrearVehiculoAsync(VehiculoRequest request);
    Task<VehiculoResponse> ActualizarVehiculoAsync(int id, VehiculoRequest request);
    Task EliminarVehiculoAsync(int id);
    Task<ResumenFlotaResponse> ResumenFlotaAsync();

    // --- Conductores ---
    Task<IEnumerable<ConductorResponse>> GetConductoresAsync();
    Task<ConductorResponse> GetConductorAsync(int id);
    Task<ConductorResponse> CrearConductorAsync(ConductorRequest request);
    Task<ConductorResponse> ActualizarConductorAsync(int id, ConductorRequest request);
    Task EliminarConductorAsync(int id);
    Task<ResumenConductoresResponse> ResumenConductoresAsync();
}
