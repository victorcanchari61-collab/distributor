namespace Backend.Dtos.Requests;

/// <summary>Una línea que el cliente devuelve.</summary>
public class LineaDevolucionRequest
{
    /// <summary>La línea de la venta que se devuelve.</summary>
    public int NotaVentaDetalleId { get; set; }

    /// <summary>Cuántas presentaciones vuelven.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Si vuelve al stock vendible. En falso entra y sale como merma.</summary>
    public bool ReingresaStock { get; set; } = true;
}

/// <summary>Lo que se devuelve de una nota de venta.</summary>
public class DevolucionRequest
{
    public int NotaVentaId { get; set; }

    /// <summary>A qué almacén vuelve la mercadería.</summary>
    public int AlmacenId { get; set; }

    public string? Motivo { get; set; }
    public string? Observacion { get; set; }

    public List<LineaDevolucionRequest> Detalle { get; set; } = [];
}

/// <summary>El rechazo tiene que decir por qué.</summary>
public class RechazarDevolucionRequest
{
    public string Motivo { get; set; } = string.Empty;
}
