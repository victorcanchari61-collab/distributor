namespace Backend.Dtos.Responses;

public class GastoRecurrenteResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public int MotivoGastoId { get; set; }
    public string MotivoGasto { get; set; } = string.Empty;
    public decimal MontoEstimado { get; set; }
    public int DiaVencimiento { get; set; }
    public int? CuentaFinancieraSugeridaId { get; set; }
    public string? CuentaFinancieraSugerida { get; set; }
    public bool Activo { get; set; }
}

/// <summary>Una plantilla recurrente que este mes todavía no tiene su pago registrado.</summary>
public class GastoPendienteResponse
{
    public int GastoRecurrenteId { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public int MotivoGastoId { get; set; }
    public string MotivoGasto { get; set; } = string.Empty;
    public decimal MontoEstimado { get; set; }
    public int? CuentaFinancieraSugeridaId { get; set; }
    public DateTime ProximoVencimiento { get; set; }
    public bool Vencido { get; set; }
}

public class MovimientoOperativoResponse
{
    public int Id { get; set; }
    public int CuentaFinancieraId { get; set; }
    public string CuentaFinanciera { get; set; } = string.Empty;
    public string Tipo { get; set; } = string.Empty;
    public int MotivoGastoId { get; set; }
    public string MotivoGasto { get; set; } = string.Empty;
    public decimal Monto { get; set; }
    public DateTime Fecha { get; set; }
    public string? Descripcion { get; set; }
    public int? GastoRecurrenteId { get; set; }
    public string? Usuario { get; set; }
    public bool Anulado { get; set; }
}
