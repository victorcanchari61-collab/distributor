namespace Backend.Dtos.Responses;

public class UsuarioResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public int RolId { get; set; }

    /// <summary>Nombre del rol, para no obligar al cliente a otra llamada.</summary>
    public string Rol { get; set; } = string.Empty;

    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }
}
