namespace Backend.Dtos.Requests;

/// <summary>Matriz completa de permisos de un rol: reemplaza a la anterior.</summary>
public class UpdatePermisosRequest
{
    public List<PermisoItem> Permisos { get; set; } = [];
}

public class PermisoItem
{
    public string Modulo { get; set; } = string.Empty;
    public bool Ver { get; set; }
    public bool Crear { get; set; }
    public bool Editar { get; set; }
    public bool Eliminar { get; set; }
}
