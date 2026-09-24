namespace Backend.Models;

public static class EstadoAsistencia
{
    public const string Presente = "PRESENTE";
    public const string Tardanza = "TARDANZA";
    public const string Falta = "FALTA";
    public const string Permiso = "PERMISO";

    public static readonly string[] Todos = [Presente, Tardanza, Falta, Permiso];
}

/// <summary>
/// Un empleado, un día: si vino, faltó, llegó tarde o tuvo permiso. Se marca
/// a mano, uno por uno — no hay reloj biométrico detrás.
///
/// No se borra ni se corrige en el sitio: una marcada por error se anula
/// (conserva el historial) y, si hacía falta otra, se registra de nuevo.
/// </summary>
public class Asistencia
{
    public int Id { get; set; }

    public int EmpleadoId { get; set; }
    public Empleado? Empleado { get; set; }

    /// <summary>Solo la fecha: la hora se ignora.</summary>
    public DateTime Fecha { get; set; }

    public string Estado { get; set; } = EstadoAsistencia.Presente;
    public string? Observacion { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaRegistro { get; set; } = DateTime.UtcNow;
    public bool Anulado { get; set; }
}
