namespace Backend.Dtos.Responses;

public class CuentaFinancieraResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Naturaleza { get; set; } = string.Empty;

    public string? Banco { get; set; }
    public string? NumeroCuenta { get; set; }
    public string? Cci { get; set; }
    public string? Titular { get; set; }

    public decimal SaldoActual { get; set; }
    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }
}

public class MovimientoCuentaResponse
{
    public int Id { get; set; }
    public int CuentaFinancieraId { get; set; }
    public string Tipo { get; set; } = string.Empty;
    public decimal Monto { get; set; }
    public decimal SaldoResultante { get; set; }
    public DateTime Fecha { get; set; }
    public string DocumentoOrigen { get; set; } = string.Empty;
    public int? OrigenId { get; set; }
    public int? MovimientoOrigenId { get; set; }
    public string? Usuario { get; set; }
    public string? Observacion { get; set; }
}
