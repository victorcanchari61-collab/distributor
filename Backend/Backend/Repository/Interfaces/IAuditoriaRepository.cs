using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IAuditoriaRepository
{
    /// <summary>Los últimos cambios, del más nuevo al más viejo, con los filtros que se pasen.</summary>
    Task<IEnumerable<RegistroAuditoria>> GetAsync(
        string? entidad, string? accion, int? usuarioId, DateTime? desde, DateTime? hasta);

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
