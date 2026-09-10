namespace Backend.Dtos.Requests;

/// <summary>
/// Lo que una persona puede cambiar de su propio perfil. A proposito no trae
/// RolId ni Activo: eso lo decide un administrador desde Usuarios, no uno mismo.
/// </summary>
public class ActualizarPerfilRequest
{
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Dni { get; set; }
    public string? Telefono { get; set; }

    /// <summary>Ruta relativa devuelta por /api/archivo/imagen. Null la quita.</summary>
    public string? Foto { get; set; }
}
