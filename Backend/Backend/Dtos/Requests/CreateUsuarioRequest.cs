namespace Backend.Dtos.Requests;

public class CreateUsuarioRequest
{
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string? Dni { get; set; }

    /// <summary>Nombre de usuario para iniciar sesión. Opcional.</summary>
    public string? NombreUsuario { get; set; }

    /// <summary>Id de la tabla Roles.</summary>
    public int RolId { get; set; }

    /// <summary>Su ficha en Empleados. Opcional: hay cuentas que no son de nadie del padrón.</summary>
    public int? EmpleadoId { get; set; }

    /// <summary>La ruta que tiene a cargo. Opcional y de cualquier usuario, no solo de vendedores.</summary>
    public int? RutaId { get; set; }
}
