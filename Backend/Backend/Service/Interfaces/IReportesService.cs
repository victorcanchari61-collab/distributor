using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// El reporte de cada dashboard (pestaña Reportes): ventas, rentabilidad, cobranza, compras,
/// inventario y reparto. Cada uno con sus vistas, filtros, columnas y totales, en un formato que
/// la pantalla y el PDF dibujan igual.
/// </summary>
public interface IReportesService
{
    /// <param name="tablero">ventas, rentabilidad, cobranza, compras, inventario o reparto.</param>
    Task<ReporteResponse> GenerarAsync(string tablero, ReporteRequest request);
}
