namespace Backend.Dtos.Responses;

public class EmpresaResponse
{
    public int Id { get; set; }
    public string RazonSocial { get; set; } = string.Empty;
    public string NombreComercial { get; set; } = string.Empty;
    public string Ruc { get; set; } = string.Empty;
    public string? Direccion { get; set; }
    public string? Departamento { get; set; }
    public string? Provincia { get; set; }
    public string? Distrito { get; set; }
    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public string? SitioWeb { get; set; }
    public string? RepresentanteLegal { get; set; }
    public bool Activa { get; set; }
    public bool Habilitada { get; set; }
    public DateTime FechaCreacion { get; set; }
}
