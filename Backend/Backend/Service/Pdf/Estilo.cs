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
    /*
     * Negro puro en TODO el texto, sin escala de grises.
     *
     * Un gris medio se ve bien en pantalla y se pierde en el papel: la
     * impresora de oficina lo saca lavado y la termica de la camioneta, que no
     * tiene medias tintas, directamente lo convierte en nada o en un punteado.
     * Un documento que se entrega a un cliente tiene que leerse tambien cuando
     * se fotocopia o se manda por WhatsApp.
     */
    public const string Fuerte = "#000000";
    public const string Texto = "#000000";
    public const string Suave = "#000000";

    public const string Linea = "#000000";
    public const string LineaSuave = "#000000";
    public const string Cabecera = "#E5E7EB";
    public const string Fondo = "#F3F4F6";

    /// <summary>Lo anulado sí va en rojo: es lo único que no puede pasar inadvertido.</summary>
    public const string Anulado = "#B91C1C";
    public const string AnuladoFondo = "#FEF2F2";

    /// <summary>Los bordes de la tabla de los A4, el gris casi negro del sistema anterior.</summary>
    public const string BordeTabla = "#363636";

    /// <summary>El recuadro del RUC y el número en los A4, más oscuro y más grueso que la tabla.</summary>
    public const string BordeRuc = "#1E1E1E";
}

/// <summary>
/// La letra de los documentos A4: DejaVu Serif en negrita, la misma del
/// sistema anterior, para que el papel se vea como el que ya conocen.
///
/// Va dentro del ensamblado y se registra con un nombre propio: así sale
/// igual en la PC y en el VPS, tenga o no el servidor esa fuente instalada.
/// Solo la negrita, porque en esos documentos todo el texto va en negrita.
/// </summary>
public static class Letra
{
    private static readonly Lazy<string> Registrada = new(() =>
    {
        const string nombre = "Serif Documento";
        using var flujo = typeof(Letra).Assembly.GetManifestResourceStream("Pdf.DejaVuSerif-Bold.ttf")
            ?? throw new InvalidOperationException("Falta la letra de los PDF (Recursos/Pdf/DejaVuSerif-Bold.ttf).");
        QuestPDF.Drawing.FontManager.RegisterFontWithCustomName(nombre, flujo);
        return nombre;
    });

    public static string Serif => Registrada.Value;
}

/// <summary>El logo de la empresa para los documentos A4, leído una sola vez.</summary>
public static class Marca
{
    private static readonly Lazy<byte[]> LogoLeido = new(() =>
    {
        using var flujo = typeof(Marca).Assembly.GetManifestResourceStream("Pdf.logo-titanic.png")
            ?? throw new InvalidOperationException("Falta el logo de los PDF (Recursos/Pdf/logo-titanic.png).");
        using var memoria = new MemoryStream();
        flujo.CopyTo(memoria);
        return memoria.ToArray();
    });

    public static byte[] Logo => LogoLeido.Value;
}

/// <summary>Cómo se escriben los números y los datos sueltos en el papel.</summary>
public static class Textos
{
    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");

    /// <summary>Un importe, siempre con dos decimales y su símbolo.</summary>
    public static string Monto(decimal valor) => "S/ " + valor.ToString("N2", Peru);

    /// <summary>Un importe sin símbolo, para las columnas de la tabla: 1,250.00.</summary>
    public static string Numero(decimal valor) => valor.ToString("N2", Peru);

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

    /// <summary>La web como se escribe en un papel: sin "https://" ni barra final.</summary>
    public static string Web(string sitio)
    {
        var limpio = sitio.Trim().ToLowerInvariant();
        foreach (var esquema in new[] { "https://", "http://" })
            if (limpio.StartsWith(esquema)) limpio = limpio[esquema.Length..];
        return limpio.TrimEnd('/');
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
