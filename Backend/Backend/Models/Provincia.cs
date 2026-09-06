namespace Backend.Models;

/// <summary>
/// Provincia del Perú (división política oficial, INEI/RENIEC). Dato de
/// referencia: no lo crea ni edita el usuario, viene precargado.
/// </summary>
public class Provincia
{
    public int Id { get; set; }

    /// <summary>Código ubigeo de 4 dígitos.</summary>
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;

    public int DepartamentoId { get; set; }
    public Departamento? Departamento { get; set; }
}
