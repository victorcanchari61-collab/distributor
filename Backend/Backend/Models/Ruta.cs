namespace Backend.Models;

/// <summary>
/// Ruta de reparto a la que pertenece un cliente.
/// </summary>
public class Ruta
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
