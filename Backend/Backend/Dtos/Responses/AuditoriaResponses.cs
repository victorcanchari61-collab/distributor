namespace Backend.Dtos.Responses;

public class AuditoriaResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }

    public int? UsuarioId { get; set; }

    /// <summary>"Sistema" cuando el cambio no vino de una sesión (migración, seed).</summary>
    public string Usuario { get; set; } = "Sistema";

    public string Entidad { get; set; } = string.Empty;
    public string EntidadId { get; set; } = string.Empty;

    /// <summary>CREADO, ACTUALIZADO o ELIMINADO.</summary>
    public string Accion { get; set; } = string.Empty;

    /// <summary>Campo → valor. En una edición solo los que cambiaron; en un alta o baja el registro entero.</summary>
    public Dictionary<string, object?>? ValoresAnteriores { get; set; }
    public Dictionary<string, object?>? ValoresNuevos { get; set; }

    /// <summary>
    /// A qué se refiere el cambio en palabras del negocio: el nombre del
    /// producto de la línea editada. Lo llena el historial de un documento —
    /// la bitácora general no sabe resolver la relación y lo deja vacío.
    /// </summary>
    public string? Descripcion { get; set; }
}
