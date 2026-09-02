namespace Backend.Dtos.Requests;

public class UpdateUsuarioRequest
{
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Dni { get; set; }

    /// <summary>Id de la tabla Roles.</summary>
    public int RolId { get; set; }

    public bool Activo { get; set; } = true;

    /// <summary>
    /// Nueva contraseña. Vacío deja la actual: editar el nombre de alguien no
    /// deberia obligar a reescribir su clave.
    /// </summary>
    public string? Password { get; set; }
}
