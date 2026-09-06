namespace Backend.Dtos.Responses;

public class LineaVentaResponse
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
    public decimal PrecioUnitario { get; set; }
    public decimal Subtotal { get; set; }

    /// <summary>Solo aplica a líneas de pedido: se quitó al editarlo, sin borrarse.</summary>
    public bool Anulado { get; set; }
}

public class PedidoResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public string Cliente { get; set; } = string.Empty;

    public int? ListaPrecioId { get; set; }
    public string? ListaPrecio { get; set; }

    public DateTime Fecha { get; set; }

    /// <summary>PENDIENTE, CONFIRMADO o ANULADO.</summary>
    public string Estado { get; set; } = string.Empty;

    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    public bool ReservaStock { get; set; }
    public int? AlmacenId { get; set; }
    public string? Almacen { get; set; }

    public decimal Total { get; set; }
    public List<LineaVentaResponse> Detalle { get; set; } = [];
}

/// <summary>Un pago parcial: un método del catálogo y cuánto se pagó con él.</summary>
public class PagoVentaResponse
{
    public int Id { get; set; }
    public int MetodoPagoId { get; set; }
    public string MetodoPago { get; set; } = string.Empty;
    public decimal Monto { get; set; }
    public DateTime Fecha { get; set; }
    public string? Usuario { get; set; }
    public bool Anulado { get; set; }
}

/// <summary>
/// Un cobro: un pago de una nota de venta, visto desde quién lo cobró en vez
/// de desde el documento. Es la base de "Mis cobros".
/// </summary>
public class CobroResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }

    public int NotaVentaId { get; set; }
    public string NotaVentaNumero { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public string Cliente { get; set; } = string.Empty;

    public int MetodoPagoId { get; set; }
    public string MetodoPago { get; set; } = string.Empty;

    public decimal Monto { get; set; }

    /// <summary>Se anuló después de registrarse: no cuenta para el total cobrado.</summary>
    public bool Anulado { get; set; }
}

public class NotaVentaResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public string Cliente { get; set; } = string.Empty;

    /// <summary>Si nació de confirmar un pedido, cuál. Null si fue directa.</summary>
    public int? PedidoId { get; set; }
    public string? PedidoNumero { get; set; }

    public int AlmacenId { get; set; }
    public string Almacen { get; set; } = string.Empty;

    public DateTime Fecha { get; set; }

    /// <summary>CONFIRMADA o ANULADA.</summary>
    public string Estado { get; set; } = string.Empty;

    /// <summary>CONTADO o CREDITO.</summary>
    public string FormaPago { get; set; } = string.Empty;

    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    public decimal Total { get; set; }
    public List<LineaVentaResponse> Detalle { get; set; } = [];

    /// <summary>Con qué se pagó. Puede ser más de un método — un pago mixto.</summary>
    public List<PagoVentaResponse> Pagos { get; set; } = [];

    /// <summary>Suma de Pagos. Si es menor que Total, falta esa diferencia por cobrar.</summary>
    public decimal TotalPagado { get; set; }
}
