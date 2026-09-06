using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IRutaRepository
{
    Task<IEnumerable<Ruta>> GetAllAsync();
    Task<Ruta?> GetByIdAsync(int id);
    Task<bool> ExisteNombreAsync(string nombre, int? excepto = null);

    /// <summary>Clientes que ya la usan.</summary>
    Task<int> ContarClientesAsync(int id);

    Task<Ruta> AddAsync(Ruta ruta);
    Task UpdateAsync(Ruta ruta);
    Task DeleteAsync(Ruta ruta);
}
