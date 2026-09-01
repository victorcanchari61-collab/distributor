namespace Backend.Dtos.Requests;

public abstract class ProveedorRequestBase
{
    public string Documento { get; set; } = string.Empty;

    /// <summary>Razon social.</summary>
    public string Nombre { get; set; } = string.Empty;
    public string? NombreComercial { get; set; }
    public string? Direccion { get; set; }
    public string? Departamento { get; set; }
    public string? Distrito { get; set; }
    public string? Telefono { get; set; }
    public string? Telefono2 { get; set; }
    public string? Email { get; set; }
    public string? Rubro { get; set; }
}
