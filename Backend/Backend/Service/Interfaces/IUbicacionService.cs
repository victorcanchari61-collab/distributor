using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Los lugares dentro de un almacén (pisos, cuartos, estantes) y qué producto está en cada uno.
///
/// Sirve para decir DÓNDE está la mercadería. El stock no se cuenta por lugar: sigue siendo por almacén.
/// </summary>
public interface IUbicacionService
{
    /// <summary>Todos los lugares del almacén, ya en orden de árbol (cada uno seguido de lo que tiene adentro).</summary>
    Task<List<UbicacionResponse>> ListarAsync(int almacenId);

    Task<UbicacionResponse> CrearAsync(int almacenId, CrearUbicacionRequest request);

    /// <summary>Crea varios lugares seguidos (E01 a E20). Si alguno ya existe no crea ninguno.</summary>
    Task<List<UbicacionResponse>> GenerarAsync(int almacenId, GenerarUbicacionesRequest request);

    Task<UbicacionResponse> ActualizarAsync(int id, ActualizarUbicacionRequest request);

    /// <summary>Solo se borra un lugar vacío: sin lugares adentro y sin productos puestos.</summary>
    Task EliminarAsync(int id);

    Task<List<UbicacionProductoResponse>> ProductosAsync(int id);
    Task<List<UbicacionProductoResponse>> AsignarProductoAsync(int id, AsignarProductoUbicacionRequest request);
    Task<List<UbicacionProductoResponse>> QuitarProductoAsync(int id, int productoId);

    /// <summary>
    /// Los productos de un almacén con el lugar donde está cada uno: los que tienen stock ahí y los que ya se pusieron
    /// en un lugar. Es la lista de trabajo de "Ubicación de productos": filtrando los que no tienen lugar se ve qué falta.
    /// </summary>
    Task<ProductosUbicadosResponse> ProductosDelAlmacenAsync(int almacenId);

    /// <summary>Pone varios productos en un lugar; con <c>Reemplazar</c>, los mueve (les quita el lugar que tenían en ese almacén).</summary>
    Task<ProductosUbicadosResponse> AsignarVariosAsync(AsignarProductosUbicacionRequest request);

    /// <summary>Saca varios productos de un lugar.</summary>
    Task<ProductosUbicadosResponse> QuitarVariosAsync(QuitarProductosUbicacionRequest request);
}
