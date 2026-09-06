using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IAuditoriaService
{
    Task<IEnumerable<AuditoriaResponse>> GetAsync(
        string? entidad, string? accion, int? usuarioId, DateTime? desde, DateTime? hasta);

    /// <summary>Una página del listado, ya buscada, filtrada y ordenada en la base.</summary>
    Task<PaginaResponse<AuditoriaResponse>> ListarAsync(ConsultaTablaRequest consulta);

    /// <summary>Contadores y valores de filtro de toda la bitácora.</summary>
    Task<ResumenAuditoriaResponse> GetResumenAsync();

    Task<IEnumerable<string>> GetEntidadesAsync();

    /// <summary>El historial de un documento y sus líneas — ver <see cref="Repository.Interfaces.IAuditoriaRepository"/>.</summary>
    Task<IEnumerable<AuditoriaResponse>> GetHistorialDocumentoAsync(
        string entidadPrincipal, int id, string entidadDetalle, IEnumerable<int> idsDetalleActuales);
}
