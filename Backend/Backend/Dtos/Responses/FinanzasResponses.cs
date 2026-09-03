namespace Backend.Dtos.Responses;

public class MetodoPagoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;

    /// <summary>EFECTIVO, BILLETERA_DIGITAL o TRANSFERENCIA.</summary>
    public string Tipo { get; set; } = string.Empty;

    public string? Banco { get; set; }
    public string? NumeroCuenta { get; set; }
    public string? Cci { get; set; }
    public string? Titular { get; set; }

    public bool Activo { get; set; }

    /// <summary>Cuántos documentos ya lo usan. Si hay alguno, no se elimina.</summary>
    public int Usos { get; set; }
}
