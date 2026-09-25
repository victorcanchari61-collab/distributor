namespace Backend.Dtos.Requests;

public class FeriadoRequest
{
    public DateTime Fecha { get; set; }
    public string Nombre { get; set; } = string.Empty;
}
