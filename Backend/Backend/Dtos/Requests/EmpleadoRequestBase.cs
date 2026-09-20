namespace Backend.Dtos.Requests;

public abstract class EmpleadoRequestBase
{
    public string Documento { get; set; } = string.Empty;

    /// <summary>DNI o CODIGO. Vacío se deduce del largo del número.</summary>
    public string? TipoDoc { get; set; }

    public string Nombres { get; set; } = string.Empty;
    public string Apellidos { get; set; } = string.Empty;

    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public string? Direccion { get; set; }
    public string? Cargo { get; set; }
    public string? Area { get; set; }
    public DateTime? FechaIngreso { get; set; }
    public DateTime? FechaCese { get; set; }
    public string? Observacion { get; set; }
}
