namespace Backend.Dtos.Responses;

public class ClienteResponse
{
    public int Id { get; set; }
    public string Documento { get; set; } = string.Empty;
    public string TipoDoc { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }
    public string? Distrito { get; set; }
    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public string? DiaVisita { get; set; }
    public string? Ruta { get; set; }
    public string? PuntoReparto { get; set; }
    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }
}
