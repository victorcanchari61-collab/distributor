namespace Backend.Models;

/// <summary>
/// Lo que un rol puede hacer en un modulo. El modulo se guarda con la misma
/// clave que usa el menu del frontend (maestros, compras, inv, fact, tms, dms,
/// rrhh, config), asi la matriz de la pantalla Accesos calza sin traducciones.
/// </summary>
public class RolPermiso
{
    public int Id { get; set; }
    public int RolId { get; set; }
    public Rol? Rol { get; set; }

    public string Modulo { get; set; } = string.Empty;

    public bool Ver { get; set; }
    public bool Crear { get; set; }
    public bool Editar { get; set; }
    public bool Eliminar { get; set; }
}
