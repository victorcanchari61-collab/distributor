namespace Backend.Models;

/// <summary>
/// Lo que se sabe de una ruta además de su nombre: dónde están sus clientes, qué días sale, cuánto vende y cuánto le
/// deben. No es una tabla: se calcula al listar las rutas.
/// </summary>
public class ResumenRuta
{
    public List<string> Mercados { get; } = [];
    public List<(string Dia, string Placa)> Salidas { get; } = [];
    public decimal VentasMes { get; set; }
    public int ClientesConCompraMes { get; set; }
    public decimal PorCobrar { get; set; }
    public int ClientesConDeuda { get; set; }
}
