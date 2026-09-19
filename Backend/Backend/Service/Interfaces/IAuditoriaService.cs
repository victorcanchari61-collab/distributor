using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IAuditoriaService
{
    Task<IEnumerable<AuditoriaResponse>> GetAsync(
        string? entidad, string? accion, int? usuarioId, DateTime? desde, DateTime? hasta);

    /// <summary>Una página del listado, ya buscada, filtrada y ordenada en la base.</summary>
    Task<PaginaResponse<AuditoriaResponse>> ListarAsync(ConsultaTablaRequest consulta);

    /// <summary>
    /// Depura la bitácora: borra todo lo que la consulta deja a la vista y
    /// devuelve cuántos registros fueron. Deja un registro que dice quién
    /// depuró, cuántos y con qué filtros — borrar la bitácora sin dejar rastro
    /// de que se borró le quitaría el sentido.
    /// </summary>
    Task<int> EliminarAsync(ConsultaTablaRequest consulta, int? usuarioId);

    /// <summary>Contadores y valores de filtro de toda la bitácora.</summary>
    Task<ResumenAuditoriaResponse> GetResumenAsync();

    Task<IEnumerable<string>> GetEntidadesAsync();

    /// <summary>El historial de un documento y sus líneas — ver <see cref="Repository.Interfaces.IAuditoriaRepository"/>.</summary>
    Task<IEnumerable<AuditoriaResponse>> GetHistorialDocumentoAsync(
        string entidadPrincipal, int id, string entidadDetalle, IEnumerable<int> idsDetalleActuales);
}
