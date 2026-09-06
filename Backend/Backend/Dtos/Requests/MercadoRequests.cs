namespace Backend.Dtos.Requests;

public abstract class MercadoRequestBase
{
    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }
    public string? Distrito { get; set; }
}

public class CreateMercadoRequest : MercadoRequestBase;

public class UpdateMercadoRequest : MercadoRequestBase
{
    public bool Activo { get; set; } = true;
}
