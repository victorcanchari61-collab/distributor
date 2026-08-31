namespace Backend.Models;

/// <summary>
/// Perfil de trabajo. Reemplaza al antiguo enum Role: ahora los roles son
/// datos, para que el administrador pueda crear los suyos sin tocar codigo.
/// </summary>
public class Rol
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activo { get; set; } = true;

    /// <summary>
    /// Roles base del sistema (Administrador, Vendedor, Almacenero). No se
    /// eliminan, porque hay permisos y autorizaciones que dependen de ellos.
    /// </summary>
    public bool DelSistema { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public ICollection<RolPermiso> Permisos { get; set; } = new List<RolPermiso>();
    public ICollection<Usuario> Usuarios { get; set; } = new List<Usuario>();
}
