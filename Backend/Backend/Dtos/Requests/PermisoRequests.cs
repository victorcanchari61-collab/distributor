using Backend.Models;

namespace Backend.Dtos.Requests;

/// <summary>Conceder a una persona algo que su rol no le da.</summary>
public class ConcederPermisoRequest
{
    public int UsuarioId { get; set; }
    public string Submodulo { get; set; } = string.Empty;
    public string Accion { get; set; } = string.Empty;
    public AlcancePermiso Alcance { get; set; }

    /// <summary>Obligatoria solo si el alcance es Temporal.</summary>
    public DateTime? ExpiraEn { get; set; }

    public string? Motivo { get; set; }
}

/// <summary>Pedir una acción con la que uno se topó bloqueado.</summary>
public class SolicitarPermisoRequest
{
    public string Submodulo { get; set; } = string.Empty;
    public string Accion { get; set; } = string.Empty;
    public string? Motivo { get; set; }

    /// <summary>El documento sobre el que iba, si venia de uno: "NV-0042".</summary>
    public string? Referencia { get; set; }
}

/// <summary>Aprobar una solicitud, eligiendo hasta cuándo vale.</summary>
public class AprobarSolicitudRequest
{
    public AlcancePermiso Alcance { get; set; }
    public DateTime? ExpiraEn { get; set; }
    public string? Respuesta { get; set; }
}

/// <summary>Rechazar una solicitud.</summary>
public class RechazarSolicitudRequest
{
    public string? Respuesta { get; set; }
}
