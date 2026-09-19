namespace Backend.Dtos.Responses;

/// <summary>
/// Cuánto se ganó con un producto: lo vendido menos lo que costó la mercadería
/// que salió.
///
/// La base de las ganancias es el producto; vendedor, venta, categoría, marca y
/// fechas son filtros que recortan qué ventas entran en la suma.
/// </summary>
public class GananciaProductoResponse
{
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string Categoria { get; set; } = string.Empty;
    public string Marca { get; set; } = string.Empty;

    /// <summary>Cuánto se vendió, en unidad base.</summary>
    public decimal Cantidad { get; set; }
    public string UnidadBase { get; set; } = string.Empty;

    /// <summary>En cuántas ventas salió.</summary>
    public int Ventas { get; set; }

    /// <summary>Los números de esas ventas: NV-0004.</summary>
    public List<string> Notas { get; set; } = [];

    /// <summary>Quién lo vendió.</summary>
    public List<string> Vendedores { get; set; } = [];

    /// <summary>El día de la última venta, en hora local.</summary>
    public DateTime UltimaVenta { get; set; }

    public decimal Importe { get; set; }
    public decimal Costo { get; set; }
    public decimal Ganancia { get; set; }

    /// <summary>Ganancia sobre lo vendido, en %. Vacío si no hubo importe.</summary>
    public decimal? Margen { get; set; }

    /// <summary>Parte de esa mercadería entró sin declarar su costo.</summary>
    public bool SinCosto { get; set; }
}

/// <summary>Los totales de TODO lo filtrado, no solo de la página que se ve.</summary>
public class GananciaResumenResponse
{
    /// <summary>El primer y el último día contados, en hora local.</summary>
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }

    /// <summary>Si lo que se ve es solo lo propio o todo el negocio.</summary>
    public bool SoloPropio { get; set; }

    public int Ventas { get; set; }
    public int Productos { get; set; }

    public decimal Importe { get; set; }
    public decimal Costo { get; set; }
    public decimal Ganancia { get; set; }
    public decimal? Margen { get; set; }

    /// <summary>
    /// Cuántas líneas vendidas no tienen costo: la mercadería entró sin
    /// declararlo. En esas la ganancia sale igual al precio y el total queda
    /// inflado — la pantalla lo avisa.
    /// </summary>
    public int LineasSinCosto { get; set; }
}

/// <summary>Lo que hay para elegir en los filtros, dentro del rango de fechas.</summary>
public class GananciaOpcionesResponse
{
    public List<string> Vendedores { get; set; } = [];
    public List<string> Categorias { get; set; } = [];
    public List<string> Marcas { get; set; } = [];

    /// <summary>Los productos que se vendieron en el rango.</summary>
    public List<string> Productos { get; set; } = [];

    /// <summary>Los números de las ventas del rango: NV-0004.</summary>
    public List<string> Ventas { get; set; } = [];
}

public class GananciaPaginaResponse : PaginaResponse<GananciaProductoResponse>
{
    public GananciaResumenResponse Resumen { get; set; } = new();
    public GananciaOpcionesResponse Opciones { get; set; } = new();
}
