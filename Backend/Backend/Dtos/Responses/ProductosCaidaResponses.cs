namespace Backend.Dtos.Responses;

/// <summary>Un tramo de días y el del tramo contra el que se compara, ya con su texto para mostrarlo.</summary>
public class PeriodoProductosResponse
{
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }
    public DateTime AnteriorDesde { get; set; }
    public DateTime AnteriorHasta { get; set; }
}

/// <summary>Un producto con lo que vendió en el tramo, lo que vendía antes y el estado que eso le da.</summary>
public class ProductoCaidaFilaResponse
{
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string? Foto { get; set; }
    public string? Marca { get; set; }
    public int? CategoriaId { get; set; }
    public string Categoria { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;

    /// <summary>El día de la última venta hasta la fecha de corte. Nulo: nunca se vendió.</summary>
    public DateTime? UltimaVenta { get; set; }
    public bool NuncaVendido { get; set; }
    public int DiasSinVenta { get; set; }

    /// <summary>Lo que hay en el almacén (o en todos), en unidad base.</summary>
    public decimal Stock { get; set; }

    /// <summary>Ese stock a su costo: lo que hay parado.</summary>
    public decimal CostoStock { get; set; }

    /// <summary>El último ingreso de mercadería al almacén.</summary>
    public DateTime? UltimaCompra { get; set; }

    /// <summary>Lo vendido en el tramo anterior y en el actual, en soles o en unidades según lo que se mide.</summary>
    public decimal Anterior { get; set; }
    public decimal Actual { get; set; }
    public decimal Variacion { get; set; }

    /// <summary>Positiva si vendió menos. Nula si el tramo anterior no vendió: no hay con qué comparar.</summary>
    public decimal? CaidaPct { get; set; }

    /// <summary>Lo que dejó de vender: el anterior menos el actual, sin bajar de cero.</summary>
    public decimal Perdida { get; set; }

    /// <summary>CRITICO, RIESGO, SEGUIMIENTO, NORMAL o SIN_BASE (sin comparación o sin ventas).</summary>
    public string Estado { get; set; } = string.Empty;
}

public class EstadoProductosResponse
{
    public string Estado { get; set; } = string.Empty;
    public int Productos { get; set; }
    public decimal CostoStock { get; set; }
    public decimal Perdida { get; set; }
}

public class CategoriaCaidaResponse
{
    public string Categoria { get; set; } = string.Empty;
    public decimal Anterior { get; set; }
    public decimal Actual { get; set; }
    public decimal Variacion { get; set; }
    public decimal? CaidaPct { get; set; }
}

/// <summary>Un punto de la evolución: lo vendido ese día (o ese mes) y lo del mismo punto del tramo anterior.</summary>
public class PuntoEvolucionResponse
{
    /// <summary>El día (AAAA-MM-DD) o el mes (AAAA-MM) del tramo actual al que corresponde el punto.</summary>
    public string Etiqueta { get; set; } = string.Empty;
    public decimal Anterior { get; set; }
    public decimal Actual { get; set; }
}

/// <summary>La evolución de un grupo de productos: todos los que cayeron, o los de un estado.</summary>
public class SerieEvolucionResponse
{
    /// <summary>"TODOS" (los que cayeron) o un estado.</summary>
    public string Clave { get; set; } = string.Empty;
    public decimal Anterior { get; set; }
    public decimal Actual { get; set; }
    public List<PuntoEvolucionResponse> Puntos { get; set; } = [];
}

public class ResumenProductosCaidaResponse
{
    public int TotalProductos { get; set; }

    /// <summary>Los que ya se enfriaron: crítico, en riesgo y en seguimiento.</summary>
    public int EnCaida { get; set; }
    public int ConStock { get; set; }
    public decimal UnidadesInmovilizadas { get; set; }

    /// <summary>El costo del stock de los que están en riesgo o críticos: lo que ya está parado.</summary>
    public decimal StockInmovilizado { get; set; }

    /// <summary>Lo que dejaron de vender los que cayeron.</summary>
    public decimal VentaPerdida { get; set; }
}

public class ProductosCaidaResponse
{
    public PeriodoProductosResponse Periodo { get; set; } = new();

    /// <summary>"mes": el tramo se compara con el mismo tramo del mes anterior. "anio": con el del año anterior.</summary>
    public string Comparar { get; set; } = "mes";

    /// <summary>"soles" o "unidades".</summary>
    public string Medida { get; set; } = "soles";

    /// <summary>"variacion" (el % que cayó) o "dias" (los días desde la última venta).</summary>
    public string Criterio { get; set; } = "variacion";

    /// <summary>"dia" o "mes": cada cuánto es un punto de la evolución.</summary>
    public string Granularidad { get; set; } = "dia";

    /// <summary>Hasta cuándo se cuentan los días sin vender: el fin del tramo, o hoy si llega al futuro.</summary>
    public DateTime Corte { get; set; }

    public ResumenProductosCaidaResponse Resumen { get; set; } = new();
    public List<EstadoProductosResponse> Estados { get; set; } = [];
    public List<CategoriaCaidaResponse> PorCategoria { get; set; } = [];
    public List<SerieEvolucionResponse> Evolucion { get; set; } = [];
    public List<ProductoCaidaFilaResponse> Items { get; set; } = [];
}
