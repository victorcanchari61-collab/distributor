using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IListaPrecioRepository
{
    Task<IEnumerable<ListaPrecio>> GetAllAsync();
    Task<ListaPrecio?> GetAsync(int id);
    Task<bool> ExisteNombreAsync(string nombre, int? excepto = null);
    Task<int> ContarPreciosAsync(int listaId);

    Task<ListaPrecio> AddAsync(ListaPrecio lista);
    Task UpdateAsync(ListaPrecio lista);
    Task DeleteAsync(ListaPrecio lista);

    /// <summary>Deja esta lista como la unica predeterminada.</summary>
    Task MarcarPredeterminadaAsync(int id);

    // --- Precios ---

    /// <summary>Precios de la lista, con presentacion y producto cargados.</summary>
    Task<IEnumerable<PrecioProducto>> GetPreciosAsync(int listaId);

    Task<PrecioProducto?> GetPrecioAsync(int id);

    /// <summary>
    /// Busca el precio de una presentacion en una lista para una cantidad
    /// minima concreta: es la clave que no se repite.
    /// </summary>
    Task<PrecioProducto?> BuscarPrecioAsync(int listaId, int presentacionId, decimal cantidadMinima);

    Task<PrecioProducto> AddPrecioAsync(PrecioProducto precio);
    Task UpdatePrecioAsync(PrecioProducto precio);
    Task DeletePrecioAsync(PrecioProducto precio);
    Task GuardarCambiosAsync();
}
