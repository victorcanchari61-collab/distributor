namespace Backend.Dtos.Requests;

public class CreateUsuarioRequest
{
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string? Dni { get; set; }

    /// <summary>Nombre de usuario para iniciar sesión. Opcional.</summary>
    public string? NombreUsuario { get; set; }

    /// <summary>Id del rol principal (tabla Roles). Lo mandan los clientes anteriores a los roles múltiples.</summary>
    public int RolId { get; set; }

    /// <summary>
    /// Todos los roles de la persona, el primero como principal. Sus permisos son la unión de los de todos.
    /// Vacío usa <see cref="RolId"/>.
    /// </summary>
    public List<int> RolIds { get; set; } = [];

    /// <summary>Su ficha en Empleados. Opcional: hay cuentas que no son de nadie del padrón.</summary>
    public int? EmpleadoId { get; set; }

    /// <summary>La ruta que tiene a cargo. Opcional y de cualquier usuario, no solo de vendedores.</summary>
    public int? RutaId { get; set; }
}
