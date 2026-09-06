namespace Backend.Models;

/// <summary>
/// Distrito del Perú (división política oficial, INEI/RENIEC). Dato de
/// referencia: no lo crea ni edita el usuario, viene precargado.
/// </summary>
public class Distrito
{
    public int Id { get; set; }

    /// <summary>Código ubigeo de 6 dígitos.</summary>
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;

    public int ProvinciaId { get; set; }
    public Provincia? Provincia { get; set; }
}
