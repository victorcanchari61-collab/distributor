using Backend.Models;

namespace Backend.Repository.Interfaces;

/// <summary>Lo que se muestra de un producto en el listado, sin abrir sus capas.</summary>
public record ResumenStock(decimal Stock, decimal Valorizado, decimal CostoMin, decimal CostoMax);

public interface IInventarioRepository
{
    // --- Almacenes ---
    Task<IEnumerable<Almacen>> GetAlmacenesAsync();
    Task<Almacen?> GetAlmacenAsync(int id);
    Task<Almacen?> GetAlmacenPrincipalAsync();
    Task<bool> ExisteCodigoAlmacenAsync(string codigo, int? excepto = null);
    Task<Almacen> AddAlmacenAsync(Almacen almacen);
    Task UpdateAlmacenAsync(Almacen almacen);

    /// <summary>Cuantas capas hay en el almacen: impide borrarlo con stock.</summary>
    Task<int> ContarCapasAlmacenAsync(int almacenId);
    Task DeleteAlmacenAsync(Almacen almacen);

    // --- Capas de costo ---

    /// <summary>
    /// Capas con mercaderia, de la mas antigua a la mas nueva: ese es el orden
    /// en que se consumen.
    /// </summary>
    Task<List<CapaCosto>> GetCapasDisponiblesAsync(int productoId, int? almacenId = null);

    /// <summary>Todas las capas del producto, incluidas las agotadas.</summary>
    Task<List<CapaCosto>> GetCapasAsync(int productoId, int? almacenId = null);

    /// <summary>Ultima entrada registrada, para conocer el costo mas reciente.</summary>
    Task<CapaCosto?> GetUltimaCapaAsync(int productoId, int? almacenId = null);

    Task<CapaCosto> AddCapaAsync(CapaCosto capa);

    /// <summary>Guarda los descuentos hechos sobre varias capas de una vez.</summary>
    Task GuardarCambiosAsync();

    /// <summary>Stock y costos de varios productos, para pintar el listado.</summary>
    Task<Dictionary<int, ResumenStock>> GetResumenAsync(IEnumerable<int> productoIds);
}
