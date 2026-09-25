namespace Backend.Dtos.Responses;

public class CierreCajaResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }
    public decimal SaldoSistema { get; set; }
    public decimal Billetes { get; set; }
    public decimal Monedas { get; set; }
    public decimal Contado { get; set; }

    /// <summary>Negativa: faltó plata. Positiva: sobró.</summary>
    public decimal Diferencia { get; set; }

    public int CuentaDestinoId { get; set; }
    public string CuentaDestino { get; set; } = string.Empty;
    public string? Observacion { get; set; }
}

/// <summary>Una cuenta a la que se puede entregar lo contado: solo lo justo para elegirla, sin su saldo.</summary>
public class CuentaDestinoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Naturaleza { get; set; } = string.Empty;
}
