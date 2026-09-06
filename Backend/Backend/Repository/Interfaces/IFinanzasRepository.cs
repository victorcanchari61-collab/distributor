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

    // --- Arqueo de caja ---

    /// <summary>Suma de pagos en efectivo de notas de venta vigentes, en la fecha dada.</summary>
    Task<decimal> GetCobradoEfectivoAsync(DateTime fecha);

    /// <summary>Suma de pagos en efectivo de compras vigentes, en la fecha dada.</summary>
    Task<decimal> GetPagadoEfectivoAsync(DateTime fecha);

    Task<ArqueoCaja?> GetArqueoAsync(DateTime fecha);
    Task<IEnumerable<ArqueoCaja>> GetHistorialArqueoAsync();

    /// <summary>
    /// Una página del historial de cierres. Reemplaza al tope de 90 días: se
    /// cierra caja todos los días, así que en tres meses el resto quedaba
    /// fuera de alcance.
    /// </summary>
    Task<(List<ArqueoCaja> Items, int Total)> ListarArqueosAsync(Dtos.Requests.ConsultaTablaRequest consulta);

    /// <summary>Crea el cierre del día, o reemplaza el que ya hubiera para esa fecha.</summary>
    Task<ArqueoCaja> GuardarArqueoAsync(ArqueoCaja arqueo);
}
