using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IAuditoriaService
{
    Task<IEnumerable<AuditoriaResponse>> GetAsync(
        string? entidad, string? accion, int? usuarioId, DateTime? desde, DateTime? hasta);

    Task<IEnumerable<string>> GetEntidadesAsync();
}
