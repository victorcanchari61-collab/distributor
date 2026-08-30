namespace Backend.Dtos.Responses;

public class ProveedorResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Ruc { get; set; } = string.Empty;
    public string? Direccion { get; set; }
    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }
}
