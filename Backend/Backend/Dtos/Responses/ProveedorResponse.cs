namespace Backend.Dtos.Responses;

public class ProveedorResponse
{
    public int Id { get; set; }

    /// <summary>El código del proveedor ("PRV00012"), sacado de su Id: automático y sin repetirse.</summary>
    public string Codigo => Models.CodigoEntidad.Proveedor(Id);
    public string Documento { get; set; } = string.Empty;
    public string TipoDoc { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? NombreComercial { get; set; }
    public string? Direccion { get; set; }
    public string? Departamento { get; set; }
    public string? Provincia { get; set; }
    public string? Distrito { get; set; }
    public string? Telefono { get; set; }
    public string? Telefono2 { get; set; }
    public string? Email { get; set; }
    public string? Rubro { get; set; }
    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }
}
