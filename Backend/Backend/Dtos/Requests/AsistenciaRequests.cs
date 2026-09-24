namespace Backend.Dtos.Requests;

public class CrearAsistenciaRequest
{
    public int EmpleadoId { get; set; }
    public DateTime Fecha { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string? Observacion { get; set; }
}

/// <summary>
/// Solo se corrige el estado y la observación: el empleado y la fecha son lo
/// que identifica la marca. Si se equivocaron de empleado o de día, se anula
/// y se registra de nuevo.
/// </summary>
public class EditarAsistenciaRequest
{
    public string Estado { get; set; } = string.Empty;
    public string? Observacion { get; set; }
}
