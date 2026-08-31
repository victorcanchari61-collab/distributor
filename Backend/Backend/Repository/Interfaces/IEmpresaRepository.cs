using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IEmpresaRepository : IRepository<Empresa>
{
    Task<Empresa?> GetActivaAsync();
    Task<bool> ExistsByRucAsync(string ruc, int? excludeId = null);
    Task<bool> AnyAsync();

    /// <summary>
    /// Deja activa unicamente a <paramref name="id"/>: desactiva al resto en
    /// una sola transaccion, para que nunca queden dos activas.
    /// </summary>
    Task SetActivaAsync(int id);

    Task DeleteAsync(Empresa empresa);
}
