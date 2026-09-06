using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IAuditoriaService
{
    Task<IEnumerable<AuditoriaResponse>> GetAsync(
        string? entidad, string? accion, int? usuarioId, DateTime? desde, DateTime? hasta);

    Task<IEnumerable<string>> GetEntidadesAsync();

    /// <summary>El historial de un documento y sus líneas — ver <see cref="Repository.Interfaces.IAuditoriaRepository"/>.</summary>
    Task<IEnumerable<AuditoriaResponse>> GetHistorialDocumentoAsync(
        string entidadPrincipal, int id, string entidadDetalle, IEnumerable<int> idsDetalleActuales);
}
