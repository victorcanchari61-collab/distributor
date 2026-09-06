namespace Backend.Models;

public enum EstadoSolicitud
{
    Pendiente = 0,
    Aprobada = 1,
    Rechazada = 2,
}

/// <summary>
/// Alguien se topó con una acción bloqueada y la pidió.
///
/// Es la otra mitad de <see cref="UsuarioPermiso"/>: el admin puede conceder
/// por su cuenta, pero lo normal es al reves — el vendedor descubre que no
/// puede anular su nota justo cuando necesita anularla, y ese es el momento en
/// que hay que dejarle pedirlo. Sin esto la peticion viaja por WhatsApp y se
/// concede sin que quede constancia de para que era.
///
/// Se guarda aunque se rechace: saber que algo se pide mucho y se niega
/// siempre es la senal de que el rol esta mal repartido.
/// </summary>
public class SolicitudPermiso
{
    public int Id { get; set; }

    /// <summary>Quien lo pide.</summary>
    public int UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public string Submodulo { get; set; } = string.Empty;
    public string Accion { get; set; } = string.Empty;

    /// <summary>Para que lo necesita. Lo escribe quien pide.</summary>
    public string? Motivo { get; set; }

    /// <summary>
    /// Sobre que documento, si venia de uno: "NV-0042". Texto y no un id
    /// porque la solicitud no sabe de que tabla salio, y lo que le sirve a
    /// quien aprueba es el numero que ve en pantalla.
    /// </summary>
    public string? Referencia { get; set; }

    public EstadoSolicitud Estado { get; set; } = EstadoSolicitud.Pendiente;

    public DateTime FechaSolicitud { get; set; } = DateTime.UtcNow;

    public int? ResueltaPorId { get; set; }
    public DateTime? FechaResolucion { get; set; }

    /// <summary>Lo que contesto quien aprueba o rechaza.</summary>
    public string? Respuesta { get; set; }

    /// <summary>El permiso que se creo al aprobarla. Nulo si se rechazo.</summary>
    public int? PermisoId { get; set; }
}
