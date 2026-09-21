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

    /// <summary>
    /// Los productos del camión, sumados por mercado, producto y presentación.
    /// Sin lo anulado.
    /// </summary>
    Task<List<LineaCargaResponse>> LineasCargaAsync(int id);

    /// <summary>
    /// Lo que entra al camión en un corte de horario (1, 2 o 3).
    ///
    /// El primero es la carga base; el segundo y el tercero son aumentos: solo
    /// la diferencia de cada línea en esa franja, en negativo si bajó. Devuelve
    /// también el día de carga que se tomó, para escribirlo en el papel.
    /// </summary>
    Task<(List<LineaCargaResponse> Lineas, DateTime DiaCarga)> LineasCargaCorteAsync(int id, int corte);

    /// <summary>Los mercados y unidades de medida que lleva el camión, para filtrar el reporte.</summary>
    Task<OpcionesCargaResponse> OpcionesCargaAsync(int id);
    Task<ResumenDespachosResponse> GetResumenAsync();

    /// <summary>
    /// Los pedidos que se pueden cargar: pendientes, de esa ruta, y que no
    /// estén ya en otro despacho vigente.
    /// </summary>
    /// <param name="diaVisita">LUNES … SABADO. Si viene, solo los clientes que se visitan ese día.</param>
    Task<IEnumerable<DespachoPedidoResponse>> PedidosDisponiblesAsync(
        IReadOnlyCollection<int> rutaIds, int? despachoId = null, string? diaVisita = null);

    Task<DespachoResponse> CrearAsync(DespachoRequest request, int? usuarioId);
    Task<DespachoResponse> ActualizarAsync(int id, DespachoRequest request);

    /// <summary>Deshace el despacho; sus pedidos vuelven a quedar libres.</summary>
    Task<DespachoResponse> AnularAsync(int id);
}
