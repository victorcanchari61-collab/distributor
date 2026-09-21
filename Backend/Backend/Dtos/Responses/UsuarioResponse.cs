namespace Backend.Dtos.Responses;

public class UsuarioResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Dni { get; set; }

    /// <summary>Nombre de usuario, si eligió uno.</summary>
    public string? NombreUsuario { get; set; }
    public string? Telefono { get; set; }

    /// <summary>Ruta relativa de la foto de perfil, si tiene.</summary>
    public string? Foto { get; set; }

    public int RolId { get; set; }

    /// <summary>Nombre del rol, para no obligar al cliente a otra llamada.</summary>
    public string Rol { get; set; } = string.Empty;

    /// <summary>Su ficha de empleado, si la tiene enlazada.</summary>
    public int? EmpleadoId { get; set; }
    public string? Empleado { get; set; }

    /// <summary>La ruta que tiene a cargo, si tiene.</summary>
    public int? RutaId { get; set; }
    public string? Ruta { get; set; }

    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }
}
