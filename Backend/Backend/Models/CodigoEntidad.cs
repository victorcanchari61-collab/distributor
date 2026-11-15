using System.Text.RegularExpressions;

namespace Backend.Models;

/// <summary>
/// El código con que se identifica a un cliente o a un proveedor: "CLI01468", "PRV00012".
///
/// Sale del Id de la base, así que es automático, no se repite, no cambia y los que ya existían lo tienen desde ya,
/// siguiendo el mismo correlativo. No se guarda en una columna: guardarlo sería tener dos números para lo mismo que se
/// pueden desalinear.
/// </summary>
public static partial class CodigoEntidad
{
    public const string PrefijoCliente = "CLI";
    public const string PrefijoProveedor = "PRV";

    public static string Cliente(int id) => $"{PrefijoCliente}{id:D5}";
    public static string Proveedor(int id) => $"{PrefijoProveedor}{id:D5}";

    /// <summary>
    /// El Id que hay detrás de un código escrito en el buscador ("cli1468", "CLI01468"), o null si el texto no es un
    /// código de ese tipo.
    /// </summary>
    public static int? IdDe(string? texto, string prefijo)
    {
        if (string.IsNullOrWhiteSpace(texto)) return null;
        var m = Codigo().Match(texto.Trim());
        return m.Success
               && m.Groups[1].Value.Equals(prefijo, StringComparison.OrdinalIgnoreCase)
               && int.TryParse(m.Groups[2].Value, out var id)
            ? id
            : null;
    }

    [GeneratedRegex(@"^([A-Za-z]{3})0*(\d{1,9})$")]
    private static partial Regex Codigo();
}
