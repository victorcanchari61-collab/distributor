namespace Backend.Models;

/// <summary>
/// Dónde se entrega: un mercado de abastos, pero también puede ser una zona
/// con tiendas o empresas — el nombre quedó "Mercado" porque es como el
/// negocio ya lo conoce, aunque no todos los puntos sean mercados literales.
/// </summary>
public class Mercado
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
