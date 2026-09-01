namespace Backend.Models;

/// <summary>
/// Tipo de documento, deducido del propio numero: 8 digitos es DNI, 11 es RUC
/// y cualquier otro largo es un codigo interno del negocio (los que vienen de
/// la hoja antigua, como 201002).
/// </summary>
public static class TipoDocumento
{
    public const string Dni = "DNI";
    public const string Ruc = "RUC";
    public const string Codigo = "CODIGO";

    public static string Deducir(string? documento) => (documento?.Trim().Length) switch
    {
        8 => Dni,
        11 => Ruc,
        _ => Codigo
    };
}
