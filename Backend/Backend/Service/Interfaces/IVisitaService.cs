using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// A quién toca visitar cada día.
///
/// No guarda nada: es una lista de trabajo armada con lo que ya está en la
/// base — el día de visita del cliente y los pedidos de esa fecha. Por eso no
/// hay un documento "visita" ni un estado que mantener al día.
/// </summary>
public interface IVisitaService
{
    /// <summary>
    /// Las visitas de un rango de días, una fila por cliente y día.
    ///
    /// Es un rango y no un día suelto para que el filtro de la tabla sea el
    /// mismo control de fechas que el resto del sistema: con desde = hasta se
    /// obtiene un día, que es el uso normal.
    /// </summary>
    Task<IEnumerable<VisitaResponse>> DelRangoAsync(
        DateTime desde, DateTime hasta, int? rutaId, int? vendedorId);

    Task<ResumenVisitasResponse> ResumenAsync(
        DateTime desde, DateTime hasta, int? rutaId, int? vendedorId);
}
