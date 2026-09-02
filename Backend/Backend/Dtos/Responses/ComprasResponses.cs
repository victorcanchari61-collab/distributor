namespace Backend.Dtos.Responses;

public class LineaCompraResponse
{
    public int Id { get; set; }
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;

    public int? PresentacionId { get; set; }
    public string? Presentacion { get; set; }
    public decimal CantidadPresentacion { get; set; }

    public decimal Cantidad { get; set; }
    public decimal CostoUnitario { get; set; }
    public decimal CostoTotal { get; set; }
}

public class OrdenCompraResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;

    public int ProveedorId { get; set; }
    public string Proveedor { get; set; } = string.Empty;

    public DateTime Fecha { get; set; }
    public DateTime? FechaEsperada { get; set; }

    /// <summary>PENDIENTE, CONFIRMADA o ANULADA.</summary>
    public string Estado { get; set; } = string.Empty;

    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    public decimal Total { get; set; }
    public List<LineaCompraResponse> Detalle { get; set; } = [];
}

public class CompraDetalleResponse
{
    public int Id { get; set; }
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;

    public int? PresentacionId { get; set; }
    public string? Presentacion { get; set; }
    public decimal CantidadPresentacion { get; set; }

    public decimal Cantidad { get; set; }
    public decimal CostoUnitario { get; set; }
    public decimal CostoTotal { get; set; }

    public decimal CantidadRecibida { get; set; }

    /// <summary>Cantidad − CantidadRecibida, en unidad base.</summary>
    public decimal CantidadPendiente { get; set; }
}

public class CompraResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;

    public int ProveedorId { get; set; }
    public string Proveedor { get; set; } = string.Empty;

    /// <summary>Si nació de confirmar una orden, cuál. Null si fue directa.</summary>
    public int? OrdenCompraId { get; set; }
    public string? OrdenCompraNumero { get; set; }

    public DateTime Fecha { get; set; }

    /// <summary>PENDIENTE, RECIBIDA_PARCIAL, RECIBIDA_TOTAL o ANULADA.</summary>
    public string Estado { get; set; } = string.Empty;

    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    public decimal Total { get; set; }
    public List<CompraDetalleResponse> Detalle { get; set; } = [];
}
