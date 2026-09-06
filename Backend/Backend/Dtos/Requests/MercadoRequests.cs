namespace Backend.Dtos.Requests;

public class CreateMercadoRequest
{
    public string Nombre { get; set; } = string.Empty;
}

public class UpdateMercadoRequest
{
    public string Nombre { get; set; } = string.Empty;
    public bool Activo { get; set; } = true;
}
