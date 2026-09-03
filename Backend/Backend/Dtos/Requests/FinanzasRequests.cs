namespace Backend.Dtos.Requests;

public abstract class MetodoPagoRequestBase
{
    public string Nombre { get; set; } = string.Empty;
}

public class CreateMetodoPagoRequest : MetodoPagoRequestBase;

public class UpdateMetodoPagoRequest : MetodoPagoRequestBase
{
    public bool Activo { get; set; } = true;
}
