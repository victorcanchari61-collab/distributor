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

/// <summary>
/// El pase de lista de un día: la marca de varios empleados de una vez. Al que
/// ya tiene marca ese día se le corrige; al que no, se le registra.
/// </summary>
public class MarcarDiaAsistenciaRequest
{
    public DateTime Fecha { get; set; }
    public List<MarcaDiaRequest> Marcas { get; set; } = [];
}

public class MarcaDiaRequest
{
    public int EmpleadoId { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string? Observacion { get; set; }
}
