namespace Backend.Models;

/// <summary>
/// Empresa emisora. Pueden registrarse varias, pero solo una puede estar
/// activa: es la que opera el sistema en un momento dado.
/// </summary>
public class Empresa
{
    public int Id { get; set; }
    public string RazonSocial { get; set; } = string.Empty;
    public string NombreComercial { get; set; } = string.Empty;
    public string Ruc { get; set; } = string.Empty;
    public string? Direccion { get; set; }
    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public bool Activa { get; set; }
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
