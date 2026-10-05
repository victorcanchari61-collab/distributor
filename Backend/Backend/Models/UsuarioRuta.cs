namespace Backend.Models;

/// <summary>
/// Una ruta que tiene a cargo un usuario. Puede tener varias: el vendedor que
/// atiende la ruta del lunes y la del jueves, o el que cubre la de un compañero.
/// </summary>
public class UsuarioRuta
{
    public int UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public int RutaId { get; set; }
    public Ruta? Ruta { get; set; }
}
