using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IAuditoriaRepository
{
    /// <summary>Los últimos cambios, del más nuevo al más viejo, con los filtros que se pasen.</summary>
    Task<IEnumerable<RegistroAuditoria>> GetAsync(
        string? entidad, string? accion, int? usuarioId, DateTime? desde, DateTime? hasta);

    /// <summary>Los nombres de entidad que ya tienen algún registro, para armar el filtro.</summary>
    Task<IEnumerable<string>> GetEntidadesAsync();
}
