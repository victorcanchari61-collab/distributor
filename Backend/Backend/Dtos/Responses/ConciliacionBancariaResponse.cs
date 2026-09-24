namespace Backend.Dtos.Responses;

public class ConciliacionBancariaResponse
{
    public int Id { get; set; }
    public int CuentaFinancieraId { get; set; }
    public string CuentaFinanciera { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }
    public decimal SaldoExtracto { get; set; }
    public decimal SaldoContable { get; set; }
    public decimal Diferencia { get; set; }
    public string? Observacion { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string? Usuario { get; set; }
    public DateTime FechaCreacion { get; set; }
}
