namespace Backend.Models;

public class Usuario
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;

    /// <summary>DNI del empleado. Se llena consultando RENIEC.</summary>
    public string? Dni { get; set; }

    public string? Telefono { get; set; }

    /// <summary>
    /// Foto de perfil. Se guarda la ruta relativa que sirve el backend, no el
    /// archivo: una imagen dentro de la fila hincharia cada listado.
    /// </summary>
    public string? Foto { get; set; }

    public string PasswordHash { get; set; } = string.Empty;

    /// <summary>Rol asignado. Antes era un enum; ahora vive en la tabla Roles.</summary>
    public int RolId { get; set; }
    public Rol? Rol { get; set; }

    /// <summary>
    /// Su ficha en el maestro de Empleados, si la tiene.
    ///
    /// Es OPCIONAL en los dos sentidos: hay empleados que nunca entran al sistema (el estibador) y
    /// cuentas que no son de nadie del padrón (soporte, el dueño). Enlazarla es lo que permite
    /// saber quién está detrás de una cuenta sin repetir aquí sus datos personales.
    /// </summary>
    public int? EmpleadoId { get; set; }

    /// <summary>
    /// La ruta que tiene a cargo: su cartera de clientes de la semana.
    ///
    /// Es un dato de la PERSONA y no del rol, a propósito: el dueño también vende y tiene la suya sin
    /// ser Vendedor. Por sí sola no restringe nada; lo que limita a "mis clientes" es el alcance de
    /// datos del rol o del usuario. Con ese alcance, quien no tiene ruta no ve ningún cliente.
    /// </summary>
    public int? RutaId { get; set; }
    public Ruta? Ruta { get; set; }
    public Empleado? Empleado { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
