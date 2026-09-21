namespace Backend.Models;

/// <summary>Un rol adicional de un usuario (el principal vive en <see cref="Usuario.RolId"/>).</summary>
public class UsuarioRol
{
    public int UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public int RolId { get; set; }
    public Rol? Rol { get; set; }
}
