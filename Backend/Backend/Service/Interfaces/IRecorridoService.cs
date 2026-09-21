using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IRecorridoService
{
    Task<RecorridoResponse> GetAsync(int vehiculoId);
    Task<RecorridoResponse> GuardarAsync(int vehiculoId, RecorridoRequest request);
}
