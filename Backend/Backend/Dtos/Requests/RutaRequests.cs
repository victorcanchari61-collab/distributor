namespace Backend.Dtos.Requests;

public abstract class RutaRequestBase
{
    public string Nombre { get; set; } = string.Empty;
}

public class CreateRutaRequest : RutaRequestBase;

public class UpdateRutaRequest : RutaRequestBase
{
    public bool Activo { get; set; } = true;
}
