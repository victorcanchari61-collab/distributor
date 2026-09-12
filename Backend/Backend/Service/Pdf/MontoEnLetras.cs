namespace Backend.Service.Pdf;

/// <summary>
/// El importe escrito con palabras: "CUARENTA Y SIETE CON 60/100 SOLES".
///
/// Va en el documento porque un número se altera con un trazo — un 1 delante
/// de 47 son 147 — y la letra no. Es la costumbre de cualquier comprobante
/// peruano, y por eso quien lo recibe la busca.
/// </summary>
public static class MontoEnLetras
{
    private static readonly string[] Unidades =
    [
        "", "UNO", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE",
        "DIEZ", "ONCE", "DOCE", "TRECE", "CATORCE", "QUINCE", "DIECISÉIS", "DIECISIETE",
        "DIECIOCHO", "DIECINUEVE", "VEINTE",
    ];

    private static readonly string[] Decenas =
    [
        "", "", "VEINTE", "TREINTA", "CUARENTA", "CINCUENTA",
        "SESENTA", "SETENTA", "OCHENTA", "NOVENTA",
    ];

    private static readonly string[] Centenas =
    [
        "", "CIENTO", "DOSCIENTOS", "TRESCIENTOS", "CUATROCIENTOS", "QUINIENTOS",
        "SEISCIENTOS", "SETECIENTOS", "OCHOCIENTOS", "NOVECIENTOS",
    ];

    /// <summary>El texto completo que va en el documento.</summary>
    public static string Soles(decimal monto)
    {
        var entero = (long)decimal.Truncate(Math.Abs(monto));
        // Se redondea a dos decimales antes de sacar los céntimos: sin esto un
        // 47.599 daría "59/100" en vez de los 60 céntimos que dice el total.
        var centimos = (int)((Math.Abs(Math.Round(monto, 2)) - entero) * 100);

        var letras = entero == 0 ? "CERO" : Escribir(entero);
        return $"{letras} CON {centimos:00}/100 SOLES";
    }

    private static string Escribir(long n) => n switch
    {
        0 => "",
        < 1_000 => Hasta999((int)n),
        < 1_000_000 => Miles(n),
        _ => Millones(n),
    };

    private static string Miles(long n)
    {
        var miles = n / 1000;
        var resto = n % 1000;
        // "MIL", nunca "UN MIL".
        var texto = miles == 1 ? "MIL" : $"{Hasta999((int)miles)} MIL";
        return resto == 0 ? texto : $"{texto} {Hasta999((int)resto)}";
    }

    private static string Millones(long n)
    {
        var millones = n / 1_000_000;
        var resto = n % 1_000_000;
        var texto = millones == 1 ? "UN MILLÓN" : $"{Escribir(millones)} MILLONES";
        return resto == 0 ? texto : $"{texto} {Escribir(resto)}";
    }

    private static string Hasta999(int n)
    {
        if (n == 100) return "CIEN";   // 100 es "CIEN"; 101 ya es "CIENTO UNO".

        var centena = n / 100;
        var resto = n % 100;
        var partes = new List<string>();

        if (centena > 0) partes.Add(Centenas[centena]);
        if (resto > 0) partes.Add(Hasta99(resto));

        return string.Join(" ", partes);
    }

    private static string Hasta99(int n)
    {
        if (n <= 20) return Unidades[n];

        var decena = n / 10;
        var unidad = n % 10;

        if (unidad == 0) return Decenas[decena];
        // Del 21 al 29 se escribe todo junto: VEINTIUNO, VEINTIDÓS...
        if (decena == 2) return "VEINTI" + Unidades[unidad].ToLowerInvariant().ToUpperInvariant();

        return $"{Decenas[decena]} Y {Unidades[unidad]}";
    }
}
