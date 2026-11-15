using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IMercadoRepository
{
    /// <summary>Cuántos clientes tiene cada mercado, de una sola consulta.</summary>
    Task<Dictionary<int, int>> ContarClientesPorMercadoAsync();

    Task<IEnumerable<Mercado>> GetAllAsync();

    /// <summary>Rutas, ventas del mes y deuda de cada mercado (o de uno solo, con <paramref name="mercadoId"/>).</summary>
    Task<Dictionary<int, ResumenMercado>> ResumenPorMercadoAsync(DateTime inicioMesUtc, int? mercadoId = null);
    Task<Mercado?> GetByIdAsync(int id);
    Task<bool> ExisteNombreAsync(string nombre, int? excepto = null);

    /// <summary>Clientes que ya lo usan.</summary>
    Task<int> ContarClientesAsync(int id);

    Task<Mercado> AddAsync(Mercado mercado);
    Task UpdateAsync(Mercado mercado);
    Task DeleteAsync(Mercado mercado);
}
