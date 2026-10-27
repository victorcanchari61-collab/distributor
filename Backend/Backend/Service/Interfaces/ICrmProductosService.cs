using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>Qué productos no se están moviendo.</summary>
public interface ICrmProductosService
{
    /// <summary>
    /// Los productos activos sin ventas en los últimos <paramref name="dias"/> días, con su stock.
    /// Con mercado o ruta, los que no se vendieron a los clientes de ESA zona aunque sí en otras.
    /// </summary>
    /// <param name="stock">"con" o "sin": deja solo los que tienen (o no) stock.</param>
    Task<CrmProductosResponse> SinVentasAsync(
        int dias, int? mercadoId, int? rutaId, int? categoriaId, string? stock);
}
