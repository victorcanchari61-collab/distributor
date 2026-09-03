namespace Backend.Dtos.Requests;

/// <summary>Una línea de una orden de compra o de una compra directa.</summary>
public class LineaCompraRequest
{
    public int ProductoId { get; set; }

    /// <summary>En qué presentación se pide. Vacío significa unidad base.</summary>
    public int? PresentacionId { get; set; }

    /// <summary>Cuántas presentaciones.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Lo que vale UNA presentación completa: el saco entero, no el kilo.</summary>
    public decimal CostoPresentacion { get; set; }
}

/// <summary>Lo que se le pide al proveedor: cabecera + líneas.</summary>
public class CrearOrdenCompraRequest
{
    public int ProveedorId { get; set; }
    public DateTime? Fecha { get; set; }
    public DateTime? FechaEsperada { get; set; }
    public string? Observacion { get; set; }
    public List<LineaCompraRequest> Detalle { get; set; } = [];
}

/// <summary>Una compra registrada directa, sin orden previa (al contado, en el momento).</summary>
public class CrearCompraRequest
{
    public int ProveedorId { get; set; }
    public DateTime? Fecha { get; set; }

    /// <summary>FACTURA, BOLETA, GUIA u OTRO. Vacío usa FACTURA.</summary>
    public string? TipoComprobante { get; set; }

    public string? SerieComprobante { get; set; }
    public string? NumeroComprobante { get; set; }

    /// <summary>CONTADO o CREDITO. Vacío usa CONTADO.</summary>
    public string? FormaPago { get; set; }

    /// <summary>Con qué se pagó, del catálogo de métodos de pago. Opcional.</summary>
    public int? MetodoPagoId { get; set; }

    public string? Observacion { get; set; }
    public List<LineaCompraRequest> Detalle { get; set; } = [];
}

/// <summary>Cuánto llegó ahora de una línea de la compra, en unidad base.</summary>
public class LineaRecepcionRequest
{
    public int CompraDetalleId { get; set; }
    public decimal Cantidad { get; set; }

    /// <summary>El lote del proveedor, si lo trae.</summary>
    public string? Lote { get; set; }

    /// <summary>Cuándo vence, si aplica.</summary>
    public DateTime? FechaVencimiento { get; set; }
}

/// <summary>Registra que llegó mercadería de una compra, total o parcialmente.</summary>
public class CrearRecepcionRequest
{
    public int CompraId { get; set; }
    public int AlmacenId { get; set; }
    public DateTime? Fecha { get; set; }
    public string? Observacion { get; set; }
    public List<LineaRecepcionRequest> Detalle { get; set; } = [];
}
