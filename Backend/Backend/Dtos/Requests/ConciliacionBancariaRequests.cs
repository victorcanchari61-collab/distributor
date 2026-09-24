namespace Backend.Dtos.Requests;

public class ConciliacionBancariaRequest
{
    public int CuentaFinancieraId { get; set; }

    /// <summary>Fecha de corte del extracto.</summary>
    public DateTime Fecha { get; set; }

    public decimal SaldoExtracto { get; set; }
    public string? Observacion { get; set; }
}
