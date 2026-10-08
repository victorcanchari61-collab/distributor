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

/// <summary>
/// Un empleado para pasar lista o filtrar la asistencia. Lo pide Asistencia con su propio permiso: no
/// hace falta poder ver la ficha completa en Empleados para marcarle el día.
///
/// Van también los desactivados: quien cesó a mitad de semana se marca hasta su fecha de cese.
/// </summary>
public class EmpleadoAsistenciaResponse
{
    public int Id { get; set; }
    public string NombreCompleto { get; set; } = string.Empty;
    public string? Cargo { get; set; }
    public bool Activo { get; set; }
    public DateTime? FechaIngreso { get; set; }
    public DateTime? FechaCese { get; set; }
}

/// <summary>Cuántos hay de cada estado en el rango consultado, para las tarjetas de arriba.</summary>
public class ResumenAsistenciaResponse
{
    public int Presentes { get; set; }
    public int Tardanzas { get; set; }
    public int Faltas { get; set; }
    public int Permisos { get; set; }
}

/// <summary>Qué hizo el pase de lista: cuántas marcas nuevas y cuántas corregidas.</summary>
public class MarcarDiaAsistenciaResponse
{
    public int Creadas { get; set; }
    public int Corregidas { get; set; }
}
