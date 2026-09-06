namespace Backend.Models;

/// <summary>
/// Departamento del Perú (división política oficial, INEI/RENIEC). Dato de
/// referencia: no lo crea ni edita el usuario, viene precargado.
/// </summary>
public class Departamento
{
    public int Id { get; set; }

    /// <summary>Código ubigeo de 2 dígitos.</summary>
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
}
