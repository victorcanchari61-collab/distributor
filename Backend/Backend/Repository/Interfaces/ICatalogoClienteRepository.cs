using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface ICatalogoClienteRepository
{
    /// <summary>Las listas de precios activas, la predeterminada primero.</summary>
    Task<List<ListaPrecio>> GetListasActivasAsync();

    /// <summary>
    /// Los productos activos con lo que hace falta para mostrarlos: categoría, marca, unidad base y
    /// presentaciones con su unidad. Sin stock ni costos.
    /// </summary>
    Task<List<Producto>> GetProductosActivosAsync();

    /// <summary>Los precios activos de una lista.</summary>
    Task<List<PrecioProducto>> GetPreciosActivosAsync(int listaId);
}
