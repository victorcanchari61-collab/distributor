namespace Backend.Models;

/// <summary>
/// Lo que se sabe de un mercado además de sus datos: qué rutas llegan, cuánto se le vende y cuánto debe. No es una
/// tabla: se calcula al listar los mercados.
/// </summary>
public class ResumenMercado
{
    public List<string> Rutas { get; } = [];
    public decimal VentasMes { get; set; }
    public decimal PorCobrar { get; set; }
}
