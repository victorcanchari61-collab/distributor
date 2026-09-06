using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IAuditoriaRepository
{
    /// <summary>Los últimos cambios, del más nuevo al más viejo, con los filtros que se pasen.</summary>
    Task<IEnumerable<RegistroAuditoria>> GetAsync(
        string? entidad, string? accion, int? usuarioId, DateTime? desde, DateTime? hasta);

    /// <summary>
    /// Una página del listado, ya buscada, filtrada y ordenada en la base.
    /// Reemplaza al tope fijo de <see cref="GetAsync"/>: la bitácora crece con
    /// cada cambio del sistema y quedaba fuera de alcance todo lo anterior a
    /// los últimos 300 registros.
    /// </summary>
    Task<(List<RegistroAuditoria> Items, int Total)> ListarAsync(ConsultaTablaRequest consulta);

    /// <summary>Conteos por acción sobre TODA la bitácora, no sobre la página visible.</summary>
    Task<ResumenAuditoriaResponse> ResumenAsync();

    /// <summary>Los nombres de entidad que ya tienen algún registro, para armar el filtro.</summary>
    Task<IEnumerable<string>> GetEntidadesAsync();

    /// <summary>
    /// El historial de un documento y sus líneas, para verlo desde el propio
    /// documento en vez de ir hasta Configuración → Auditoría: los cambios de
    /// cabecera (<paramref name="entidadPrincipal"/> con <paramref name="id"/>)
    /// más los de sus líneas (<paramref name="entidadDetalle"/> cuyo id esté en
    /// <paramref name="idsDetalleActuales"/> — las líneas nunca se borran, solo
    /// se anulan, así que esta lista ya cubre toda su historia).
    /// </summary>
    Task<IEnumerable<RegistroAuditoria>> GetHistorialDocumentoAsync(
        string entidadPrincipal, int id, string entidadDetalle, IEnumerable<int> idsDetalleActuales);
}
