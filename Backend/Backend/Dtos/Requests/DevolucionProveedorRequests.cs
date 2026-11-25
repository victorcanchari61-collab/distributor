namespace Backend.Dtos.Requests;

/// <summary>Lo que se le devuelve al proveedor de una compra.</summary>
public class CrearDevolucionProveedorRequest
{
    public int CompraId { get; set; }

    /// <summary>Por qué se devuelve: llegó en mal estado, vencido, no es lo pedido...</summary>
    public string Motivo { get; set; } = string.Empty;

    public string? Observacion { get; set; }

    /// <summary>De qué almacén sale lo que ya había llegado. Obligatorio si alguna línea es de lo recibido.</summary>
    public int? AlmacenId { get; set; }

    /// <summary>Cuándo traerá el proveedor lo que repone, si alguna línea es reposición.</summary>
    public DateTime? FechaReposicion { get; set; }

    /// <summary>La nota de crédito que emite el proveedor, si la emite.</summary>
    public string? SerieNotaCredito { get; set; }
    public string? NumeroNotaCredito { get; set; }

    public List<LineaDevolucionProveedorRequest> Detalle { get; set; } = [];
}

public class LineaDevolucionProveedorRequest
{
    public int CompraDetalleId { get; set; }

    /// <summary>En unidad base.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>RECIBIDO (sale del stock) o PENDIENTE (nunca llegó).</summary>
    public string Origen { get; set; } = string.Empty;

    /// <summary>REPOSICION o DESCUENTO.</summary>
    public string Resolucion { get; set; } = string.Empty;
}

/// <summary>El proveedor devuelve la plata de un saldo a favor: entra a una caja o banco.</summary>
public class CobrarSaldoProveedorRequest
{
    public decimal Monto { get; set; }
    public int MetodoPagoId { get; set; }

    /// <summary>En efectivo, entra a la Bóveda y no a la caja de quien lo recibe.</summary>
    public bool DesdeBoveda { get; set; }

    public string? Observacion { get; set; }
}

/// <summary>Usar el saldo a favor para pagar (en parte o todo) otra compra del mismo proveedor.</summary>
public class AplicarSaldoProveedorRequest
{
    public decimal Monto { get; set; }
}
