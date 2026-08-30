using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IClienteRepository : IRepository<Cliente>
{
    Task<Cliente?> GetByRucAsync(string ruc);
    Task<bool> ExistsByRucAsync(string ruc, int? excludeId = null);
}
