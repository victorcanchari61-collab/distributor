namespace Backend.Dtos.Requests;

public abstract class RolRequestBase
{
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
}
