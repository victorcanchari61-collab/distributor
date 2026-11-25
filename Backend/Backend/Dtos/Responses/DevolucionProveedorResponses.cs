namespace Backend.Dtos.Responses;

public class DevolucionProveedorResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;

    public int CompraId { get; set; }
    public string CompraNumero { get; set; } = string.Empty;

    public int ProveedorId { get; set; }
    public string Proveedor { get; set; } = string.Empty;

    public DateTime Fecha { get; set; }

    /// <summary>CONFIRMADA o ANULADA.</summary>
    public string Estado { get; set; } = string.Empty;

    public string Motivo { get; set; } = string.Empty;
    public string? Observacion { get; set; }

    public int? AlmacenId { get; set; }
    public string? Almacen { get; set; }

    /// <summary>El documento de inventario con el que salió del stock (SP-0001), si salió algo.</summary>
    public string? DocumentoInventario { get; set; }

    public DateTime? FechaReposicion { get; set; }
    public string? SerieNotaCredito { get; set; }
    public string? NumeroNotaCredito { get; set; }

    /// <summary>Lo que bajó el total de la compra.</summary>
    public decimal MontoDescuento { get; set; }

    /// <summary>De lo descontado, lo que ya estaba pagado y quedó como saldo a favor.</summary>
    public decimal SaldoFavorGenerado { get; set; }

    /// <summary>Lo que se mandó a reponer, a su costo (llegue o no).</summary>
    public decimal MontoReposicion { get; set; }

    /// <summary>De lo que se mandó a reponer, lo que todavía no llega, a su costo. Cero si ya llegó todo.</summary>
    public decimal MontoPorReponer { get; set; }

    public string? Usuario { get; set; }

    public List<DevolucionProveedorLineaResponse> Detalle { get; set; } = [];
}

public class DevolucionProveedorLineaResponse
{
    public int Id { get; set; }
    public int CompraDetalleId { get; set; }
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;
    public string? Presentacion { get; set; }

    /// <summary>En unidad base.</summary>
    public decimal Cantidad { get; set; }
    public decimal CostoUnitario { get; set; }
    public decimal Importe { get; set; }

    /// <summary>RECIBIDO o PENDIENTE.</summary>
    public string Origen { get; set; } = string.Empty;

    /// <summary>REPOSICION o DESCUENTO.</summary>
    public string Resolucion { get; set; } = string.Empty;

    /// <summary>Si es reposición, cuánto de esta línea todavía no llega (en unidad base).</summary>
    public decimal CantidadPorReponer { get; set; }
}

/// <summary>Un proveedor que debe devolver plata (o descontarla de la próxima compra).</summary>
public class SaldoFavorProveedorResponse
{
    public int ProveedorId { get; set; }
    public string Proveedor { get; set; } = string.Empty;
    public decimal Saldo { get; set; }

    /// <summary>Todo lo que generaron sus devoluciones, cobrado o no.</summary>
    public decimal TotalGenerado { get; set; }

    public DateTime UltimoMovimiento { get; set; }
}

/// <summary>Una línea del libro del saldo a favor de un proveedor.</summary>
public class MovimientoSaldoProveedorResponse
{
    public int Id { get; set; }

    /// <summary>GENERADO, COBRADO o APLICADO.</summary>
    public string Tipo { get; set; } = string.Empty;

    public decimal Monto { get; set; }
    public DateTime Fecha { get; set; }

    /// <summary>De dónde viene: la devolución (DVP-0001) o la compra en la que se usó (CP-000123).</summary>
    public string? Documento { get; set; }

    /// <summary>Con qué devolvió la plata el proveedor, si es un cobro.</summary>
    public string? MetodoPago { get; set; }

    public bool Anulado { get; set; }
    public string? Observacion { get; set; }
    public string? Usuario { get; set; }
}
