using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;

namespace Backend.Service.Interfaces;

/// <summary>Una línea vendida, con lo que costó la mercadería que salió por ella.</summary>
public sealed record LineaGanancia(
    int NotaVentaId,
    string Venta,
    DateTime Fecha,
    string Vendedor,
    int ProductoId,
    string Codigo,
    string Producto,
    string Categoria,
    string Marca,
    string UnidadBase,
    decimal Cantidad,
    decimal Importe,
    decimal Costo,
    bool AfectoIgv)
{
    /// <summary>
    /// Lo vendido SIN el IGV: la ganancia real es esto menos el costo, no
    /// Importe menos costo — Importe ya trae el 18% que no es ingreso, es
    /// plata que se cobra para pasársela al fisco.
    /// </summary>
    public decimal ValorVenta => AfectoIgv ? Importe / (1 + Impuestos.TasaIgv) : Importe;
}

/// <summary>
/// Lo vendido en un rango, sumado en la base: importe, costo y cuántas ventas.
/// Los recojos ya vienen restados.
/// </summary>
public sealed record TotalesVenta(
    decimal Importe,
    decimal ImporteAfecto,
    decimal Costo,
    int Ventas,
    int LineasSinCosto)
{
    /// <summary>Lo vendido SIN el IGV de las líneas afectas: la venta real del negocio.</summary>
    public decimal ValorVenta => ImporteAfecto / (1 + Impuestos.TasaIgv) + (Importe - ImporteAfecto);

    /// <summary>El IGV cobrado: plata que se le pasa al fisco, no ingreso.</summary>
    public decimal Igv => Importe - ValorVenta;
}

/// <summary>Cuánto se ganó con cada producto vendido.</summary>
public interface IGananciaService
{
    /// <summary>
    /// Una página de productos con su ganancia, más los totales de todo lo
    /// filtrado. Los filtros son fecha, vendedor, venta, categoría y marca; sin
    /// fechas, lo que va del mes. Lo que se ve lo recorta el alcance de quien
    /// pregunta.
    /// </summary>
    Task<GananciaPaginaResponse> ListarAsync(ConsultaTablaRequest consulta);

    /// <summary>
    /// Las líneas vendidas en [inicioUtc, finUtc) con su costo real, recortadas
    /// al alcance de quien pregunta. Lo usa el dashboard para no calcular la
    /// ganancia por su cuenta.
    /// </summary>
    Task<(List<LineaGanancia> Lineas, bool SoloPropio)> LineasAsync(DateTime inicioUtc, DateTime finUtc);

    /// <summary>
    /// Lo vendido en [inicioUtc, finUtc) de TODO el negocio, sin recortar por
    /// el alcance de quien pregunta: lo usa el estado de resultados, que es el
    /// resultado de la empresa y no el de un vendedor.
    /// </summary>
    Task<TotalesVenta> TotalesAsync(DateTime inicioUtc, DateTime finUtc);
}
