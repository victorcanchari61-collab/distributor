namespace Backend.Models;

public class Usuario
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;

    /// <summary>
    /// Correo. OPCIONAL: no todo el que usa el sistema tiene uno (el repartidor, el del mostrador). Quien no lo
    /// tiene entra con su DNI, así que una cuenta necesita al menos uno de los dos.
    /// </summary>
    public string? Email { get; set; }

    /// <summary>
    /// Nombre de usuario: lo que se ELIGE para entrar ("jperez"), sin depender de tener correo.
    ///
    /// Opcional y único. Sirve, junto con el correo y el DNI, para iniciar sesión. Se le exige al menos una
    /// letra para que nunca se confunda con un DNI (solo dígitos) ni con un correo (lleva arroba).
    /// </summary>
    public string? NombreUsuario { get; set; }

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
    /// Los demás roles de la persona, además del principal (<see cref="RolId"/>).
    ///
    /// Una misma persona puede hacer varias cosas —vender y llevar el almacén—, y crearle un rol nuevo para cada
    /// combinación obligaría a inventar roles. Sus permisos son la UNIÓN de los de todos sus roles: tener más
    /// roles nunca le quita nada. El principal se conserva porque es el que se muestra y el que usa lo que ya
    /// leía un solo rol.
    /// </summary>
    public ICollection<UsuarioRol> RolesAdicionales { get; set; } = [];

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
