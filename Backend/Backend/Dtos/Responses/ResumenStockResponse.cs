namespace Backend.Dtos.Responses;

/// <summary>
/// Totales del stock de TODO el catálogo, no de la página visible. Salen de
/// agregados sobre las capas de costo, sin traerse las filas.
/// </summary>
public class ResumenStockResponse
{
    public int ConStock { get; set; }
    public int BajoMinimo { get; set; }
    public decimal Valorizado { get; set; }
}
