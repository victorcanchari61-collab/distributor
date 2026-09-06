using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IMercadoRepository
{
    Task<IEnumerable<Mercado>> GetAllAsync();
    Task<Mercado?> GetByIdAsync(int id);
    Task<bool> ExisteNombreAsync(string nombre, int? excepto = null);

    /// <summary>Clientes que ya lo usan.</summary>
    Task<int> ContarClientesAsync(int id);

    Task<Mercado> AddAsync(Mercado mercado);
    Task UpdateAsync(Mercado mercado);
    Task DeleteAsync(Mercado mercado);
}
