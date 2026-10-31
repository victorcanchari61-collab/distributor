namespace Backend.Dtos.Requests;

/// <summary>Emitir una factura o una boleta a partir de una nota de venta.</summary>
public class EmitirComprobanteRequest
{
    public int NotaVentaId { get; set; }

    /// <summary>01 factura o 03 boleta.</summary>
    public string Tipo { get; set; } = string.Empty;
}

/// <summary>Crear o corregir una serie de comprobantes de una empresa.</summary>
public class GuardarSerieRequest
{
    /// <summary>01 factura, 03 boleta, 07 nota de crédito, 08 nota de débito.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>Cuatro caracteres: F001, B001, FC01...</summary>
    public string Serie { get; set; } = string.Empty;

    /// <summary>Solo notas: 01 si corrigen facturas, 03 si corrigen boletas.</summary>
    public string? AplicaA { get; set; }

    /// <summary>El último número ya emitido; el siguiente comprobante será este más uno.</summary>
    public int UltimoNumero { get; set; }

    public bool Activa { get; set; } = true;
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
