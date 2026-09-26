namespace Backend.Models;

/// <summary>
/// Funciones de MySQL que se usan dentro de una consulta LINQ. No se llaman en
/// C#: EF las traduce a SQL (ver el registro en AppDbContext.OnModelCreating).
/// </summary>
public static class FuncionesSql
{
    /// <summary>
    /// JSON_LENGTH: cuántas claves tiene un objeto JSON guardado como texto.
    /// Sirve para contar los campos de un cambio de auditoría sin traer el JSON.
    /// </summary>
    public static int? JsonLength(string? json) =>
        throw new NotSupportedException("Solo se usa dentro de una consulta a la base.");
}
