using System.Globalization;
using Backend.Dtos.Responses;

namespace Backend.Service.Pdf;

/// <summary>
/// Los grises del papel.
///
/// Deliberadamente sin color de marca: esto se imprime, y casi siempre en
/// blanco y negro. Un azul corporativo sale gris claro en la impresora de la
/// oficina y desaparece del todo en la térmica de la camioneta.
/// </summary>
public static class Colores
{
    public const string Fuerte = "#111827";
    public const string Texto = "#374151";
    public const string Suave = "#6B7280";

    public const string Linea = "#9CA3AF";
    public const string LineaSuave = "#E5E7EB";
    public const string Cabecera = "#F3F4F6";
    public const string Fondo = "#F9FAFB";

    /// <summary>Lo anulado sí va en rojo: es lo único que no puede pasar inadvertido.</summary>
    public const string Anulado = "#B91C1C";
    public const string AnuladoFondo = "#FEF2F2";
}

/// <summary>Cómo se escriben los números y los datos sueltos en el papel.</summary>
public static class Textos
{
    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");

    /// <summary>Un importe, siempre con dos decimales y su símbolo.</summary>
    public static string Monto(decimal valor) => "S/ " + valor.ToString("N2", Peru);

    /// <summary>
    /// Una cantidad sin decimales de adorno.
    ///
    /// Se venden 3 sacos, no "3.000" — pero medio kilo es 0.5 y ese decimal sí
    /// importa, así que solo se recortan los ceros que no dicen nada.
    /// </summary>
    public static string Cantidad(decimal valor)
    {
        var limpio = valor == decimal.Truncate(valor) ? valor.ToString("N0", Peru) : valor.ToString("0.###", Peru);
        return limpio;
    }

    /// <summary>Une lo que exista y devuelve null si no quedó nada que escribir.</summary>
    public static string? Juntar(string separador, params string?[] partes)
    {
        var vivas = partes.Where(p => !string.IsNullOrWhiteSpace(p)).ToArray();
        return vivas.Length == 0 ? null : string.Join(separador, vivas);
    }

    /// <summary>Distrito, provincia y departamento, sin repetir lo que se repite.</summary>
    public static string? Zona(EmpresaResponse empresa)
    {
        var partes = new[] { empresa.Distrito, empresa.Provincia, empresa.Departamento }
            .Where(p => !string.IsNullOrWhiteSpace(p))
            .Select(p => p!.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return partes.Length == 0 ? null : string.Join(", ", partes);
    }
}
