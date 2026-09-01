using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IProveedorRepository : IRepository<Proveedor>
{
    Task<Proveedor?> GetByDocumentoAsync(string documento);
    Task<bool> ExistsByDocumentoAsync(string documento, int? excludeId = null);

    /// <summary>Borrado definitivo.</summary>
    Task DeleteAsync(Proveedor entidad);
}
