namespace Backend.Dtos.Responses;

public class AsistenciaResponse
{
    public int Id { get; set; }
    public int EmpleadoId { get; set; }
    public string Empleado { get; set; } = string.Empty;
    public string? Cargo { get; set; }
    public DateTime Fecha { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string? Observacion { get; set; }
    public string? Usuario { get; set; }
    public DateTime FechaRegistro { get; set; }
    public bool Anulado { get; set; }
}

/// <summary>Cuántos hay de cada estado en el rango consultado, para las tarjetas de arriba.</summary>
public class ResumenAsistenciaResponse
{
    public int Presentes { get; set; }
    public int Tardanzas { get; set; }
    public int Faltas { get; set; }
    public int Permisos { get; set; }
}
