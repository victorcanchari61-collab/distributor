using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Los números de los dashboards, ya resumidos para dibujarlos.
///
/// Un bloque por dashboard, cada uno con su propio permiso ("dashboard.ventas",
/// "dashboard.inventario"...): quien puede ver uno no ve por eso los demás.
/// </summary>
public interface IDashboardService
{
    /// <summary>Ventas del período contra el anterior, avance del mes, quién y cuándo compra.</summary>
    Task<DashboardVentasResponse> VentasAsync(DateTime? desde, DateTime? hasta);

    /// <summary>Ganancia y margen del período, y qué productos la dejan.</summary>
    Task<DashboardGananciasResponse> GananciasAsync(DateTime? desde, DateTime? hasta);

    /// <summary>Lo que se debe, cuánto hace que se debe y lo que se cobró.</summary>
    Task<DashboardCobranzaResponse> CobranzaAsync(DateTime? desde, DateTime? hasta);

    /// <summary>Qué se acaba, qué está parado y qué vence.</summary>
    Task<DashboardInventarioResponse> InventarioAsync();

    /// <summary>Pedidos, entrega y novedades del período.</summary>
    Task<DashboardRepartoResponse> RepartoAsync(DateTime? desde, DateTime? hasta);
}
