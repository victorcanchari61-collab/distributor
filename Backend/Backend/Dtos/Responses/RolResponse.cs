namespace Backend.Dtos.Responses;

public class RolResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activo { get; set; }
    public bool DelSistema { get; set; }

    /// <summary>
    /// Rol que no se puede desactivar ni eliminar: sin Administrador activo
    /// nadie podria volver a configurar el sistema.
    /// </summary>
    public bool Protegido { get; set; }
    public DateTime FechaCreacion { get; set; }

    /// <summary>Cuantos usuarios tienen este rol.</summary>
    public int Usuarios { get; set; }

    public List<RolPermisoResponse> Permisos { get; set; } = [];
}

public class RolPermisoResponse
{
    /// <summary>Clave del menú: "fact.pedidos".</summary>
    public string Submodulo { get; set; } = string.Empty;

    /// <summary>Ver, crear, editar, anular, exportar...</summary>
    public string Accion { get; set; } = string.Empty;
}
