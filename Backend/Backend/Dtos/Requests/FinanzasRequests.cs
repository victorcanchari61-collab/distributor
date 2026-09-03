namespace Backend.Dtos.Requests;

public abstract class MetodoPagoRequestBase
{
    public string Nombre { get; set; } = string.Empty;

    /// <summary>EFECTIVO, BILLETERA_DIGITAL o TRANSFERENCIA.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>Requerido en transferencia; opcional en billetera digital.</summary>
    public string? Banco { get; set; }

    /// <summary>Cuenta (transferencia) o celular (billetera). Requerido en ambos.</summary>
    public string? NumeroCuenta { get; set; }

    public string? Cci { get; set; }
    public string? Titular { get; set; }
}

public class CreateMetodoPagoRequest : MetodoPagoRequestBase;

public class UpdateMetodoPagoRequest : MetodoPagoRequestBase
{
    public bool Activo { get; set; } = true;
}
