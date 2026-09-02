namespace Backend.Models;

/// <summary>
/// Donde se guarda la mercaderia. El sistema arranca con uno principal: quien
/// tenga un solo deposito nunca lo elige, y quien abra otro no tiene que
/// rehacer nada porque el stock ya se lleva por almacen.
/// </summary>
public class Almacen
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }

    /// <summary>El que se usa cuando no se indica otro.</summary>
    public bool EsPrincipal { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
