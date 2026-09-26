using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IRutaRepository
{
    /// <summary>Cuántos clientes tiene cada ruta, de una sola consulta.</summary>
    Task<Dictionary<int, int>> ContarClientesPorRutaAsync();

    /// <summary>Quiénes atienden cada ruta, de una sola consulta.</summary>
    Task<Dictionary<int, List<string>>> VendedoresPorRutaAsync();

    Task<IEnumerable<Ruta>> GetAllAsync();
    Task<Ruta?> GetByIdAsync(int id);
    Task<bool> ExisteNombreAsync(string nombre, int? excepto = null);

    /// <summary>Clientes que ya la usan.</summary>
    Task<int> ContarClientesAsync(int id);

    /// <summary>Recorridos de vehículo y despachos que la usan.</summary>
    Task<int> ContarUsosEnRepartoAsync(int id);

    /// <summary>Nombres de quienes la tienen a cargo, activos primero.</summary>
    Task<List<string>> VendedoresAsync(int id);

    Task<Ruta> AddAsync(Ruta ruta);
    Task UpdateAsync(Ruta ruta);
    Task DeleteAsync(Ruta ruta);
}
