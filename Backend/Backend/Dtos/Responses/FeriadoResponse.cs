namespace Backend.Dtos.Responses;

public class FeriadoResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }
    public string Nombre { get; set; } = string.Empty;
}
