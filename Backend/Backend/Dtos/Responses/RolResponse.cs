namespace Backend.Dtos.Responses;

public class RolResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activo { get; set; }
    public bool DelSistema { get; set; }
    public DateTime FechaCreacion { get; set; }

    /// <summary>Cuantos usuarios tienen este rol.</summary>
    public int Usuarios { get; set; }

    public List<RolPermisoResponse> Permisos { get; set; } = [];
}

public class RolPermisoResponse
{
    public string Modulo { get; set; } = string.Empty;
    public bool Ver { get; set; }
    public bool Crear { get; set; }
    public bool Editar { get; set; }
    public bool Eliminar { get; set; }
}
