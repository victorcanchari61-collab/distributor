namespace Backend.Dtos.Requests;

/// <summary>
/// Lo que un rol puede hacer, tal cual queda tras editar la matriz de Accesos.
/// Es un reemplazo completo: lo que no viene en la lista, se retira.
/// </summary>
public class UpdatePermisosRequest
{
    public List<PermisoItem> Permisos { get; set; } = [];
}

/// <summary>Una accion concedida sobre un submodulo.</summary>
public class PermisoItem
{
    /// <summary>Clave del menu: "fact.pedidos".</summary>
    public string Submodulo { get; set; } = string.Empty;

    /// <summary>Ver, crear, editar, anular, exportar...</summary>
    public string Accion { get; set; } = string.Empty;
}
