namespace Backend.Dtos.Responses;

public class LineaDevolucionResponse
{
    public int Id { get; set; }
    public int NotaVentaDetalleId { get; set; }

    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;
    public string? Presentacion { get; set; }

    public decimal CantidadPresentacion { get; set; }
    public decimal Cantidad { get; set; }
    public decimal PrecioUnitario { get; set; }
    public decimal Importe { get; set; }

    public bool ReingresaStock { get; set; }
}

public class DevolucionResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }

    public int NotaVentaId { get; set; }
    public string NotaVenta { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public string Cliente { get; set; } = string.Empty;

    public int AlmacenId { get; set; }
    public string Almacen { get; set; } = string.Empty;

    /// <summary>SOLICITADA, APROBADA o RECHAZADA.</summary>
    public string Estado { get; set; } = string.Empty;

    public string? Motivo { get; set; }
    public string? Observacion { get; set; }
    public string? MotivoRechazo { get; set; }

    public string? Usuario { get; set; }
    public string? AprobadoPor { get; set; }
    public DateTime? ResueltaEn { get; set; }

    public decimal Total { get; set; }
    public List<LineaDevolucionResponse> Detalle { get; set; } = [];
}

/// <summary>Una línea de la venta, con lo que ya se devolvió de ella.</summary>
public class LineaDevolvibleResponse
{
    public int NotaVentaDetalleId { get; set; }
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;
    public string? Presentacion { get; set; }

    public decimal Vendida { get; set; }

    /// <summary>Lo ya devuelto: aprobado, más lo que espera aprobación.</summary>
    public decimal Devuelta { get; set; }

    /// <summary>Vendida − devuelta: el tope de esta devolución.</summary>
    public decimal Disponible { get; set; }

    public decimal PrecioUnitario { get; set; }
}

public class ResumenDevolucionesResponse
{
    public int Total { get; set; }
    public int Solicitadas { get; set; }
    public int Aprobadas { get; set; }

    /// <summary>Lo aprobado en importe: lo que se le descontó a los clientes.</summary>
    public decimal Importe { get; set; }
}
