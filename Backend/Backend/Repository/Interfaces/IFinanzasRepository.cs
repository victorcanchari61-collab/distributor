using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IFinanzasRepository
{
    // --- Métodos de pago ---
    Task<IEnumerable<MetodoPago>> GetMetodosPagoAsync();
    Task<MetodoPago?> GetMetodoPagoAsync(int id);
    Task<bool> ExisteNombreMetodoPagoAsync(string nombre, int? excepto = null);
    Task<MetodoPago> AddMetodoPagoAsync(MetodoPago metodo);
    Task UpdateMetodoPagoAsync(MetodoPago metodo);
    Task DeleteMetodoPagoAsync(MetodoPago metodo);
    Task<int> ContarUsosMetodoPagoAsync(int metodoPagoId);
}
