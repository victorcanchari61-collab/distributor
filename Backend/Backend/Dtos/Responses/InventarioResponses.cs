namespace Backend.Dtos.Responses;

public class AlmacenResponse
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }
    public bool EsPrincipal { get; set; }
    public bool Activo { get; set; }
}

public class CapaCostoResponse
{
    public int Id { get; set; }
    public int ProductoId { get; set; }
    public int AlmacenId { get; set; }
    public string Almacen { get; set; } = string.Empty;

    public decimal CantidadInicial { get; set; }
    public decimal CantidadDisponible { get; set; }

    /// <summary>Costo por unidad base, flete incluido.</summary>
    public decimal CostoUnitario { get; set; }

    /// <summary>Cuánto vale lo que queda de esta capa.</summary>
    public decimal Valor { get; set; }

    public string Origen { get; set; } = string.Empty;
    public string? Referencia { get; set; }
    public DateTime Fecha { get; set; }
}

/// <summary>Resumen de stock y costo de un producto.</summary>
public class StockProductoResponse
{
    public int ProductoId { get; set; }
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;

    /// <summary>Suma de lo que queda en todas las capas, en unidad base.</summary>
    public decimal Stock { get; set; }

    /// <summary>Costo de la capa más antigua que aún tiene mercadería.</summary>
    public decimal? CostoAntiguo { get; set; }

    /// <summary>Costo de la última entrada.</summary>
    public decimal? CostoUltimo { get; set; }

    /// <summary>Cuánto vale el stock: suma de cantidad × costo de cada capa.</summary>
    public decimal Valorizado { get; set; }

    /// <summary>Capas con mercadería, de la más antigua a la más nueva.</summary>
    public List<CapaCostoResponse> Capas { get; set; } = [];
}

/// <summary>Qué costó una salida y de qué capas salió.</summary>
public class CostoSalidaResponse
{
    public int ProductoId { get; set; }
    public decimal Cantidad { get; set; }

    /// <summary>Lo que costó esa mercadería, sumando lo tomado de cada capa.</summary>
    public decimal Costo { get; set; }

    /// <summary>Costo promedio de esta salida: Costo / Cantidad.</summary>
    public decimal CostoUnitarioPromedio { get; set; }

    public List<ConsumoCapaResponse> Consumos { get; set; } = [];
}

public class ConsumoCapaResponse
{
    public int CapaId { get; set; }
    public decimal Cantidad { get; set; }
    public decimal CostoUnitario { get; set; }
    public decimal Subtotal { get; set; }
    public DateTime Fecha { get; set; }
}
