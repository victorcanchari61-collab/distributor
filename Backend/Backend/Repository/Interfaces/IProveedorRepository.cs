using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IProveedorRepository : IRepository<Proveedor>
{
    Task<Proveedor?> GetByRucAsync(string ruc);
    Task<bool> ExistsByRucAsync(string ruc, int? excludeId = null);
}
