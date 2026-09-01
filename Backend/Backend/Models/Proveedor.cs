namespace Backend.Models;

public class Proveedor
{
    public int Id { get; set; }

    /// <summary>RUC, DNI o codigo interno. Ver <see cref="TipoDocumento"/>.</summary>
    public string Documento { get; set; } = string.Empty;
    public string TipoDoc { get; set; } = TipoDocumento.Codigo;

    /// <summary>Razon social.</summary>
    public string Nombre { get; set; } = string.Empty;
    public string? NombreComercial { get; set; }

    public string? Direccion { get; set; }
    public string? Departamento { get; set; }
    public string? Distrito { get; set; }
    public string? Telefono { get; set; }
    public string? Telefono2 { get; set; }
    public string? Email { get; set; }

    /// <summary>Que vende: "FIDEOS Y HARINAS", "PRODUCTOS IMPORTADOS".</summary>
    public string? Rubro { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
