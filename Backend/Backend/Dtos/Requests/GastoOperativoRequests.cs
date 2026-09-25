namespace Backend.Dtos.Requests;

/// <summary>Una categoría de ingresos y egresos manuales (antes "motivo de gasto").</summary>
public class CategoriaMovimientoRequest
{
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }

    /// <summary>INGRESO o EGRESO.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>OPERATIVO o NO_OPERATIVO.</summary>
    public string Origen { get; set; } = string.Empty;

    public bool Activo { get; set; } = true;
}

public class GastoRecurrenteRequest
{
    public string Nombre { get; set; } = string.Empty;
    public int MotivoGastoId { get; set; }
    public decimal MontoEstimado { get; set; }

    /// <summary>1-31.</summary>
    public int DiaVencimiento { get; set; }

    public int? CuentaFinancieraSugeridaId { get; set; }
    public bool Activo { get; set; } = true;
}

public class MovimientoOperativoRequest
{
    public int CuentaFinancieraId { get; set; }

    /// <summary>INGRESO o EGRESO.</summary>
    public string Tipo { get; set; } = string.Empty;

    public int MotivoGastoId { get; set; }
    public decimal Monto { get; set; }
    public DateTime? Fecha { get; set; }
    public string? Descripcion { get; set; }

    /// <summary>Si esto paga una plantilla recurrente pendiente.</summary>
    public int? GastoRecurrenteId { get; set; }
}
