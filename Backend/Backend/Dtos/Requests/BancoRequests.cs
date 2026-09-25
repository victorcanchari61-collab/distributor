namespace Backend.Dtos.Requests;

public class BancoRequest
{
    public string Nombre { get; set; } = string.Empty;
    public bool Activo { get; set; } = true;
}
