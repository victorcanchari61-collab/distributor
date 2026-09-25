namespace Backend.Dtos.Requests;

public class CrearFinanciamientoRequest
{
    public string Acreedor { get; set; } = string.Empty;
    public string? Descripcion { get; set; }

    /// <summary>Cuándo entró la plata. Vacío: ahora.</summary>
    public DateTime? Fecha { get; set; }

    public decimal MontoRecibido { get; set; }

    /// <summary>Lo pactado a devolver con intereses. Vacío: lo mismo que se recibió.</summary>
    public decimal? TotalADevolver { get; set; }

    /// <summary>A qué cuenta entró.</summary>
    public int CuentaFinancieraId { get; set; }
}

public class PagoFinanciamientoRequest
{
    public decimal Monto { get; set; }

    /// <summary>Cuándo se pagó. Vacío: ahora.</summary>
    public DateTime? Fecha { get; set; }

    /// <summary>De qué cuenta sale.</summary>
    public int CuentaFinancieraId { get; set; }

    public string? Observacion { get; set; }
}
