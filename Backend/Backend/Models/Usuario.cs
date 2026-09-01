namespace Backend.Models;

public class Usuario
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;

    /// <summary>DNI del empleado. Se llena consultando RENIEC.</summary>
    public string? Dni { get; set; }
    public string PasswordHash { get; set; } = string.Empty;

    /// <summary>Rol asignado. Antes era un enum; ahora vive en la tabla Roles.</summary>
    public int RolId { get; set; }
    public Rol? Rol { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
