namespace Backend.Dtos.Requests;

public class UpdateUsuarioRequest
{
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Dni { get; set; }

    /// <summary>Nombre de usuario para iniciar sesión. Opcional.</summary>
    public string? NombreUsuario { get; set; }

    /// <summary>Id del rol principal (tabla Roles). Lo mandan los clientes anteriores a los roles múltiples.</summary>
    public int RolId { get; set; }

    /// <summary>Todos los roles de la persona, el primero como principal. Vacío usa <see cref="RolId"/>.</summary>
    public List<int> RolIds { get; set; } = [];

    /// <summary>Su ficha en Empleados. Null la desenlaza.</summary>
    public int? EmpleadoId { get; set; }

    /// <summary>La ruta que tiene a cargo. Null la quita.</summary>
    public int? RutaId { get; set; }

    public bool Activo { get; set; } = true;

    /// <summary>
    /// Nueva contraseña. Vacío deja la actual: editar el nombre de alguien no
    /// deberia obligar a reescribir su clave.
    /// </summary>
    public string? Password { get; set; }
}
