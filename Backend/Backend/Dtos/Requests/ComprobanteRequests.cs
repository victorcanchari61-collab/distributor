namespace Backend.Dtos.Requests;

/// <summary>Emitir una factura o una boleta a partir de una nota de venta.</summary>
public class EmitirComprobanteRequest
{
    public int NotaVentaId { get; set; }

    /// <summary>01 factura o 03 boleta.</summary>
    public string Tipo { get; set; } = string.Empty;
}

/// <summary>Una línea de una nota de crédito o débito.</summary>
public class LineaNotaRequest
{
    public string Descripcion { get; set; } = string.Empty;
    public decimal Cantidad { get; set; }

    /// <summary>Precio por unidad. Con IGV si la línea es gravada, como en la venta.</summary>
    public decimal Precio { get; set; }

    public bool AfectoIgv { get; set; } = true;
}

/// <summary>
/// Emitir una nota de crédito o débito sobre un comprobante ya aceptado. Sin líneas, una nota de crédito repite
/// las del comprobante (anulación o devolución total).
/// </summary>
public class EmitirNotaRequest
{
    /// <summary>07 crédito o 08 débito.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>Catálogo 09 (crédito) o 10 (débito) de SUNAT.</summary>
    public string CodMotivo { get; set; } = string.Empty;

    public string DesMotivo { get; set; } = string.Empty;

    public List<LineaNotaRequest>? Lineas { get; set; }
}
