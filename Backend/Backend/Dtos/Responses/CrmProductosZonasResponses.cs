namespace Backend.Dtos.Responses;

// ------------------------------------------------------------------ Productos sin ventas

/// <summary>Un producto activo que no se vendió en los últimos días.</summary>
public class CrmProductoSinVentaResponse
{
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public int? CategoriaId { get; set; }
    public string? Categoria { get; set; }
    public string? Marca { get; set; }
    public string UnidadBase { get; set; } = string.Empty;

    /// <summary>Lo que hay en todos los almacenes, en unidad base.</summary>
    public decimal Stock { get; set; }

    /// <summary>Ese stock a su costo: la plata que está parada.</summary>
    public decimal ValorStock { get; set; }

    /// <summary>El día de la última venta (de la zona, si se filtró por una). Nulo: nunca se vendió.</summary>
    public DateTime? UltimaVenta { get; set; }

    public int? DiasSinVender { get; set; }

    /// <summary>
    /// Con filtro de mercado o ruta: lo que sí se vendió de este producto en el mismo periodo en el
    /// resto de las zonas. Si es mayor que cero, el producto se mueve, pero no ahí.
    /// </summary>
    public decimal VendidoEnOtrasZonas { get; set; }
}

public class CrmProductosResumenResponse
{
    public int ProductosActivos { get; set; }
    public int SinVentas { get; set; }

    /// <summary>De los que no se vendieron, cuántos tienen stock.</summary>
    public int ConStock { get; set; }

    /// <summary>De los que no se vendieron, cuántos no tienen stock.</summary>
    public int SinStock { get; set; }

    /// <summary>Nunca se vendieron.</summary>
    public int NuncaVendidos { get; set; }

    /// <summary>El costo del stock de los que no se vendieron.</summary>
    public decimal CapitalParado { get; set; }
}

public class CrmProductosResponse
{
    public int Dias { get; set; }

    /// <summary>El rango de días revisado, ambos incluidos.</summary>
    public RangoResponse Rango { get; set; } = new();

    public string? Mercado { get; set; }
    public string? Ruta { get; set; }

    public CrmProductosResumenResponse Resumen { get; set; } = new();
    public List<CrmProductoSinVentaResponse> Items { get; set; } = [];
}
// ------------------------------------------------------------------ Mercados y rutas

/// <summary>Un mercado o una ruta, con cómo les va a sus clientes frente al mismo tramo del año anterior.</summary>
public class ZonaCaidaResponse
{
    /// <summary>Nulo: los clientes que no tienen mercado (o ruta) asignado.</summary>
    public int? ZonaId { get; set; }

    public string Nombre { get; set; } = string.Empty;

    /// <summary>Clientes activos de la zona.</summary>
    public int Clientes { get; set; }

    /// <summary>Los que compraron en alguno de los dos tramos.</summary>
    public int ConVentas { get; set; }

    public int Criticos { get; set; }
    public int EnRiesgo { get; set; }
    public int EnSeguimiento { get; set; }
    public int SinComparacion { get; set; }

    public decimal VentaAnterior { get; set; }
    public decimal VentaActual { get; set; }
    public decimal Variacion { get; set; }

    /// <summary>Positiva si la zona cayó. Nula si el año anterior no vendió.</summary>
    public decimal? CaidaPct { get; set; }

    /// <summary>Lo que dejaron de comprar los clientes que bajaron, sin que las subidas la tapen.</summary>
    public decimal VentaPerdida { get; set; }

    public decimal SaldoPorCobrar { get; set; }
}

public class ZonasCaidaResponse
{
    public PeriodoCaidaResponse Periodo { get; set; } = new();

    /// <summary>mercado o ruta.</summary>
    public string Agrupar { get; set; } = string.Empty;

    public bool SoloPropios { get; set; }

    /// <summary>La que más plata perdió, primero.</summary>
    public List<ZonaCaidaResponse> Items { get; set; } = [];
}
