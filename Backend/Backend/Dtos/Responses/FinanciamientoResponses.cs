namespace Backend.Dtos.Responses;

public class FinanciamientoResponse
{
    public int Id { get; set; }
    public string Acreedor { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public DateTime Fecha { get; set; }
    public decimal MontoRecibido { get; set; }
    public decimal TotalADevolver { get; set; }
    public decimal Pagado { get; set; }
    public decimal Saldo { get; set; }
    public string Estado { get; set; } = string.Empty;
    public int CuentaFinancieraId { get; set; }
    public string CuentaFinanciera { get; set; } = string.Empty;
    public string? Usuario { get; set; }
    public List<PagoFinanciamientoResponse> Pagos { get; set; } = [];
}

public class PagoFinanciamientoResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }
    public decimal Monto { get; set; }
    public int CuentaFinancieraId { get; set; }
    public string CuentaFinanciera { get; set; } = string.Empty;
    public bool Anulado { get; set; }
    public string? Usuario { get; set; }
    public string? Observacion { get; set; }
}
