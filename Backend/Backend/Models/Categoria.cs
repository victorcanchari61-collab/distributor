namespace Backend.Models;

/// <summary>Familia comercial del producto: Abarrotes, Aceites, Fideos...</summary>
public class Categoria
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
