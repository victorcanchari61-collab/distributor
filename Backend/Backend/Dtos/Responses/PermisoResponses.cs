using Backend.Models;

namespace Backend.Dtos.Responses;

/// <summary>Una excepción concedida a una persona.</summary>
public class UsuarioPermisoResponse
{
    public int Id { get; set; }
    public int UsuarioId { get; set; }
    public string Submodulo { get; set; } = string.Empty;
    public string Accion { get; set; } = string.Empty;
    public AlcancePermiso Alcance { get; set; }
    public DateTime? ExpiraEn { get; set; }
    public int Usos { get; set; }
    public bool Revocado { get; set; }
    public string? Motivo { get; set; }
    public DateTime FechaOtorgado { get; set; }

    /// <summary>
    /// Si ahora mismo sirve. Lo calcula el servidor para que la pantalla no
    /// tenga que repetir las reglas de vencimiento y consumo.
    /// </summary>
    public bool Vigente { get; set; }
}

/// <summary>Una solicitud, tal como la ve la bandeja del admin.</summary>
public class SolicitudPermisoResponse
{
    public int Id { get; set; }
    public int UsuarioId { get; set; }

    /// <summary>Nombre de quien pide, para no tener que cruzar la lista de usuarios.</summary>
    public string Usuario { get; set; } = string.Empty;

    public string Submodulo { get; set; } = string.Empty;
    public string Accion { get; set; } = string.Empty;
    public string? Motivo { get; set; }
    public string? Referencia { get; set; }
    public EstadoSolicitud Estado { get; set; }
    public DateTime FechaSolicitud { get; set; }
    public DateTime? FechaResolucion { get; set; }
    public string? Respuesta { get; set; }
}
