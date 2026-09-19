using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

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
}
