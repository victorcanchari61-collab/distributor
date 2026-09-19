using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

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
    decimal Costo);

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
}
