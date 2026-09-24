namespace Backend.Dtos.Requests;

public class CuentaFinancieraRequest
{
    public string Nombre { get; set; } = string.Empty;

    /// <summary>CAJA, BANCO o PASARELA.</summary>
    public string Naturaleza { get; set; } = string.Empty;

    /// <summary>Solo aplica si Naturaleza es Banco o Pasarela.</summary>
    public string? Banco { get; set; }
    public string? NumeroCuenta { get; set; }
    public string? Cci { get; set; }
    public string? Titular { get; set; }

    public bool Activo { get; set; } = true;
}
