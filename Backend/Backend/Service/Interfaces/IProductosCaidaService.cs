using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Productos con caída: cuánto vende cada producto en un tramo frente al mismo tramo del mes anterior (o del año
/// anterior), y en qué estado está por eso o por los días que lleva sin venderse.
/// </summary>
public interface IProductosCaidaService
{
    /// <param name="comparar">"mes" (por defecto) o "anio": contra qué tramo se compara.</param>
    /// <param name="medida">"soles" (por defecto) o "unidades".</param>
    /// <param name="criterio">"variacion" (por defecto, el % que cayó) o "dias" (los días sin vender).</param>
    /// <param name="almacenId">Medir solo en un almacén (la última venta y el stock son los de ese almacén).</param>
    /// <param name="incluirSinStock">Con false solo se miden los productos que tienen stock.</param>
    Task<ProductosCaidaResponse> AnalisisAsync(
        DateTime? desde, DateTime? hasta, string? comparar, string? medida, string? criterio,
        int? almacenId, int? categoriaId, int? marcaId, bool incluirSinStock);
}
