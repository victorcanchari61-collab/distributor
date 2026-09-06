namespace Backend.Dtos.Requests;

/// <summary>
/// Lo que una tabla del sistema le pide al servidor: qué página, qué texto
/// busca, cómo ordena y qué filtros tiene puestos.
///
/// Es el espejo exacto del estado de `SysDataTable` en el front, para que la
/// tabla no tenga que traducir nada: manda su estado tal cual y el servidor
/// devuelve solo esa página. Sirve para cualquier listado, no solo clientes.
/// </summary>
public class ConsultaTablaRequest
{
    /// <summary>Empieza en 1.</summary>
    public int Pagina { get; set; } = 1;

    public int PorPagina { get; set; } = 30;

    /// <summary>Buscador general: se aplica sobre las columnas de texto del listado.</summary>
    public string? Buscar { get; set; }

    /// <summary>Columna por la que se ordena. Vacío = el orden natural del listado.</summary>
    public string? Orden { get; set; }

    /// <summary>asc o desc.</summary>
    public string? Sentido { get; set; }

    public List<FiltroTablaRequest> Filtros { get; set; } = [];

    /// <summary>La página pedida, acotada a un rango con sentido.</summary>
    public int PaginaSegura => Pagina < 1 ? 1 : Pagina;

    /// <summary>
    /// Cuántas filas por página. Se corta en 200 para que nadie pida la tabla
    /// entera cambiando el número a mano en la URL.
    /// </summary>
    public int PorPaginaSegura => PorPagina switch
    {
        < 1 => 30,
        > 200 => 200,
        _ => PorPagina
    };
}

/// <summary>Un filtro puesto sobre una columna.</summary>
public class FiltroTablaRequest
{
    public string Columna { get; set; } = string.Empty;

    /// <summary>contains (por defecto), equals o between.</summary>
    public string Operador { get; set; } = "contains";

    public string? Valor { get; set; }

    /// <summary>Solo en `between`: el extremo de arriba del rango.</summary>
    public string? ValorHasta { get; set; }
}
