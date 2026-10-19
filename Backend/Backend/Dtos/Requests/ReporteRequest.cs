using Microsoft.AspNetCore.Http;

namespace Backend.Dtos.Requests;

/// <summary>
/// Lo que se pide a un reporte: fechas, vista, búsqueda y filtros.
///
/// Los filtros llegan como <c>f.cliente=...</c> en la query: cada reporte tiene los suyos, y uno
/// nuevo no obliga a tocar este contrato.
/// </summary>
public class ReporteRequest
{
    public DateTime? Desde { get; set; }
    public DateTime? Hasta { get; set; }
    public string? Vista { get; set; }
    public string? Buscar { get; set; }
    public Dictionary<string, string> Filtros { get; set; } = [];

    /// <summary>El valor de un filtro, o null si no se eligió.</summary>
    public string? Filtro(string clave) =>
        Filtros.TryGetValue(clave, out var valor) && !string.IsNullOrWhiteSpace(valor) ? valor.Trim() : null;

    public static ReporteRequest DesdeQuery(IQueryCollection query)
    {
        static DateTime? Fecha(string? texto) => DateTime.TryParse(texto, out var f) ? f.Date : null;
        static string? Texto(string? texto) => string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

        return new ReporteRequest
        {
            Desde = Fecha(query["desde"]),
            Hasta = Fecha(query["hasta"]),
            Vista = Texto(query["vista"]),
            Buscar = Texto(query["buscar"]),
            Filtros = query
                .Where(q => q.Key.StartsWith("f.", StringComparison.Ordinal) && !string.IsNullOrWhiteSpace(q.Value))
                .ToDictionary(q => q.Key[2..], q => q.Value.ToString()),
        };
    }
}
