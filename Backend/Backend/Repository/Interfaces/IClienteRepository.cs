using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IClienteRepository : IRepository<Cliente>
{
    Task<Cliente?> GetByDocumentoAsync(string documento);
    Task<bool> ExistsByDocumentoAsync(string documento, int? excludeId = null);

    /// <summary>Borrado definitivo.</summary>
    Task DeleteAsync(Cliente entidad);
}
