using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// El reparto del día: qué pedidos van en qué camión.
///
/// No factura ni mueve stock. Eso ocurre después, cuando el repartidor
/// convierte cada pedido en venta al entregarlo.
/// </summary>
public interface IDespachoService
{
    Task<IEnumerable<DespachoResponse>> GetAllAsync(string? estado = null);
    Task<DespachoResponse> GetAsync(int id);
    Task<ResumenDespachosResponse> GetResumenAsync();

    /// <summary>
    /// Los pedidos que se pueden cargar: pendientes, de esa ruta, y que no
    /// estén ya en otro despacho vigente.
    /// </summary>
    Task<IEnumerable<DespachoPedidoResponse>> PedidosDisponiblesAsync(int rutaId, int? despachoId = null);

    Task<DespachoResponse> CrearAsync(DespachoRequest request, int? usuarioId);
    Task<DespachoResponse> ActualizarAsync(int id, DespachoRequest request);

    /// <summary>Deshace el despacho; sus pedidos vuelven a quedar libres.</summary>
    Task<DespachoResponse> AnularAsync(int id);
}
