using Backend.Models.Enums;

namespace Backend.Dtos.Responses;

public class UsuarioResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public Role Role { get; set; }
    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }
}
