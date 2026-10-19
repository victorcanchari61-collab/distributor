namespace Backend.Dtos.Responses;

/// <summary>Cómo se muestra un valor del reporte, en pantalla y en el PDF.</summary>
public static class TipoDato
{
    public const string Texto = "texto";
    public const string Entero = "entero";
    public const string Cantidad = "cantidad";
    public const string Moneda = "moneda";
    public const string Porcentaje = "porcentaje";
    public const string Fecha = "fecha";
}

/// <summary>Una columna del reporte.</summary>
public class ColumnaReporte
{
    /// <summary>La llave del valor en cada fila.</summary>
    public string Clave { get; set; } = string.Empty;
    public string Titulo { get; set; } = string.Empty;
    public string Tipo { get; set; } = TipoDato.Texto;

    /// <summary>Otra llave de la fila que va debajo, más chica: el código y la categoría de un producto.</summary>
    public string? Apoyo { get; set; }

    /// <summary>Se resalta; si es un monto negativo, va en rojo (una pérdida).</summary>
    public bool Destacada { get; set; }

    /// <summary>Lleva total en la fila de totales.</summary>
    public bool Suma { get; set; }

    /// <summary>
    /// Para un porcentaje que es un cociente (el margen): su total no se suma, se calcula como
    /// Numerador / Denominador × 100 con los totales de esas dos columnas.
    /// </summary>
    public string? Numerador { get; set; }
    public string? Denominador { get; set; }

    /// <summary>Ancho fijo en el PDF, en puntos; 0 es el que sobre.</summary>
    public float Ancho { get; set; }
}

/// <summary>Una forma de ver el reporte: "por producto", "por cliente"...</summary>
public class VistaReporte
{
    public string Id { get; set; } = string.Empty;
    public string Texto { get; set; } = string.Empty;
}

/// <summary>Una opción de un filtro de lista: el valor que viaja y lo que se lee.</summary>
public class OpcionReporte
{
    public string Valor { get; set; } = string.Empty;
    public string Texto { get; set; } = string.Empty;
}

/// <summary>Un filtro de lista, con sus opciones: solo lo que hay en esas fechas.</summary>
public class FiltroReporte
{
    public string Clave { get; set; } = string.Empty;
    public string Titulo { get; set; } = string.Empty;
    public List<OpcionReporte> Opciones { get; set; } = [];
}

/// <summary>Un indicador de arriba: total vendido, deuda, etc.</summary>
public class ResumenReporte
{
    public string Titulo { get; set; } = string.Empty;
    public decimal Valor { get; set; }
    public string Tipo { get; set; } = TipoDato.Moneda;
    public string? Nota { get; set; }

    /// <summary>sys, neutral, success, warning o danger.</summary>
    public string Tono { get; set; } = "neutral";
}

/// <summary>
/// El reporte de un dashboard, ya armado: qué columnas tiene, sus filas, sus totales y con qué
/// se puede filtrar. La pantalla y el PDF lo dibujan tal cual, sin saber de qué dashboard es.
/// </summary>
public class ReporteResponse
{
    public string Tablero { get; set; } = string.Empty;
    public string Titulo { get; set; } = string.Empty;

    /// <summary>La vista elegida y las posibles.</summary>
    public string Vista { get; set; } = string.Empty;
    public List<VistaReporte> Vistas { get; set; } = [];

    /// <summary>Si las fechas filtran algo; el inventario es una foto de hoy y no las lleva.</summary>
    public bool ConFechas { get; set; }
    public DateTime? Desde { get; set; }
    public DateTime? Hasta { get; set; }

    public List<ColumnaReporte> Columnas { get; set; } = [];

    /// <summary>Cada fila, con sus valores por la clave de la columna. "clave" la identifica.</summary>
    public List<Dictionary<string, object?>> Filas { get; set; } = [];
    public Dictionary<string, object?> Totales { get; set; } = [];

    public List<FiltroReporte> Filtros { get; set; } = [];
    public List<ResumenReporte> Resumen { get; set; } = [];

    /// <summary>Un aviso arriba de la tabla: "la deuda es la de hoy; las fechas filtran los cobros".</summary>
    public string? Aviso { get; set; }

    /// <summary>La nota al pie: cómo se calcula lo que no es obvio.</summary>
    public string? Nota { get; set; }

    /// <summary>Lo filtrado, en palabras, para el PDF. Null sin filtros.</summary>
    public string? Filtrado { get; set; }
}
