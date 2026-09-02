namespace Backend.Models;

/// <summary>Marca del producto: Primor, Costeño, Gloria...</summary>
public class Marca
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
