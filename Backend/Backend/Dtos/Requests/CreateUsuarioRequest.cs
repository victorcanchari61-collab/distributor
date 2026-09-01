namespace Backend.Dtos.Requests;

public class CreateUsuarioRequest
{
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string? Dni { get; set; }

    /// <summary>Id de la tabla Roles.</summary>
    public int RolId { get; set; }
}
