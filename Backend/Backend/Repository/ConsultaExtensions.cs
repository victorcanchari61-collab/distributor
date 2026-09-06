using Backend.Dtos.Requests;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository;

/// <summary>
/// Lo mecanico de un listado paginado, igual para todas las entidades: contar
/// el total y cortar la pagina. Lo que SI cambia en cada una — sobre que
/// columnas se busca, filtra y ordena — se queda en su repositorio, porque
/// depende de sus campos.
/// </summary>
public static class ConsultaExtensions
{
    /// <summary>
    /// El total tras los filtros (para saber cuantas paginas hay) y solo las
    /// filas de la pagina pedida. La consulta debe venir ya ordenada: paginar
    /// sobre un orden indefinido repite o saltea filas entre paginas.
    /// </summary>
    public static async Task<(List<T> Items, int Total)> PaginarAsync<T>(
        this IQueryable<T> query, ConsultaTablaRequest consulta)
    {
        var total = await query.CountAsync();

        var items = await query
            .Skip((consulta.PaginaSegura - 1) * consulta.PorPaginaSegura)
            .Take(consulta.PorPaginaSegura)
            .ToListAsync();

        return (items, total);
    }

    /// <summary>El filtro puesto sobre una columna, si la vista puso alguno.</summary>
    public static FiltroTablaRequest? Filtro(this ConsultaTablaRequest consulta, string columna) =>
        consulta.Filtros.FirstOrDefault(f => f.Columna == columna);

    /// <summary>
    /// El texto de un filtro de columna, ya limpio. Null si no hay filtro o si
    /// vino vacio.
    /// </summary>
    public static string? ValorDe(this ConsultaTablaRequest consulta, string columna)
    {
        var valor = consulta.Filtro(columna)?.Valor?.Trim();
        return string.IsNullOrEmpty(valor) ? null : valor;
    }

    /// <summary>
    /// Los dos extremos de un filtro de fecha. El "hasta" se estira al final
    /// del dia: quien filtra hasta el 5 no espera perder lo del 5 a las 3pm.
    /// </summary>
    public static (DateTime? Desde, DateTime? Hasta) RangoFechas(
        this ConsultaTablaRequest consulta, string columna)
    {
        var filtro = consulta.Filtro(columna);
        if (filtro is null) return (null, null);

        DateTime? desde = DateTime.TryParse(filtro.Valor, out var d) ? d : null;
        DateTime? hasta = DateTime.TryParse(filtro.ValorHasta, out var h)
            ? h.Date.AddDays(1).AddTicks(-1)
            : null;

        return (desde, hasta);
    }
}
