namespace Backend.Models;

public static class AccionAuditoria
{
    public const string Creado = "CREADO";
    public const string Actualizado = "ACTUALIZADO";
    public const string Eliminado = "ELIMINADO";
}

/// <summary>
/// Un cambio en el sistema: qué entidad, qué se le hizo, quién y cuándo.
///
/// Lo escribe el propio <see cref="Data.AppDbContext"/> al guardar, para
/// cualquier entidad — no hay que acordarse de registrarlo desde cada
/// servicio. Los valores van como JSON: los que cambiaron en una edición, o
/// el registro completo en un alta o una baja.
/// </summary>
public class RegistroAuditoria
{
    public int Id { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    /// <summary>Null si el cambio no vino de una petición con sesión (una migración, un seed).</summary>
    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    /// <summary>Nombre de la entidad: "Compra", "Producto", "Usuario"...</summary>
    public string Entidad { get; set; } = string.Empty;

    /// <summary>La clave del registro tocado, como texto para servir a cualquier tabla.</summary>
    public string EntidadId { get; set; } = string.Empty;

    /// <summary>CREADO, ACTUALIZADO o ELIMINADO.</summary>
    public string Accion { get; set; } = string.Empty;

    public string? ValoresAnteriores { get; set; }
    public string? ValoresNuevos { get; set; }
}
