namespace Backend.Dtos.Responses;

/// <summary>Una orden de compra que nació de la solicitud.</summary>
public class OrdenDeSolicitudResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;
    public string Estado { get; set; } = string.Empty;
}

/// <summary>Una fila del listado de solicitudes.</summary>
public class SolicitudCompraFilaResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }

    public int AlmacenId { get; set; }
    public string Almacen { get; set; } = string.Empty;

    public string Urgencia { get; set; } = string.Empty;
    public string Estado { get; set; } = string.Empty;
    public string? Observacion { get; set; }
    public string? MotivoRechazo { get; set; }

    /// <summary>Cuándo se rechazó o se atendió. Null mientras espera.</summary>
    public DateTime? FechaRespuesta { get; set; }

    /// <summary>Quién la pidió.</summary>
    public int? UsuarioId { get; set; }
    public string? Solicitante { get; set; }

    public int Lineas { get; set; }

    /// <summary>Las órdenes de compra que se hicieron con ella.</summary>
    public List<OrdenDeSolicitudResponse> Ordenes { get; set; } = [];
}

public class LineaSolicitudCompraResponse
{
    public int Id { get; set; }
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;

    public int? PresentacionId { get; set; }
    public string? Presentacion { get; set; }
    public decimal Factor { get; set; } = 1;

    public decimal CantidadPresentacion { get; set; }
    public decimal Cantidad { get; set; }
    public string? Nota { get; set; }

    /// <summary>Lo que Compras suele pagar por una presentación, para sugerirlo al armar la orden. Null si no hay.</summary>
    public decimal? CostoSugerido { get; set; }
}

public class SolicitudCompraResponse : SolicitudCompraFilaResponse
{
    public List<LineaSolicitudCompraResponse> Detalle { get; set; } = [];
}

/// <summary>Un producto que está bajo su mínimo en el almacén, con lo que se sugiere pedir.</summary>
public class SugerenciaSolicitudResponse
{
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;
    public decimal Stock { get; set; }
    public decimal StockMinimo { get; set; }

    /// <summary>En unidad base: lo que falta para llegar al doble del mínimo.</summary>
    public decimal CantidadSugerida { get; set; }
}
