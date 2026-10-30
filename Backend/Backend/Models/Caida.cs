namespace Backend.Models;

/// <summary>
/// En qué estado está un cliente según cuánto cayeron sus compras frente al mismo tramo del año anterior.
///
/// Es la escala de siempre del negocio: Crítico (71 % o más), En riesgo (26 a 70 %), En seguimiento (11 a 25 %) y
/// Normal (0 a 10 %, o si compra más que antes). Si el año anterior no compró en ese tramo no hay caída que medir:
/// queda "Sin comparación". El estado de la ficha de Gestión y seguimiento y el de los reportes son siempre el mismo.
/// </summary>
public static class EstadoCaida
{
    public const string Critico = "CRITICO";
    public const string Riesgo = "RIESGO";
    public const string Seguimiento = "SEGUIMIENTO";
    public const string Normal = "NORMAL";
    public const string SinBase = "SIN_BASE";

    /// <summary>De mayor a menor gravedad, que es el orden de las tarjetas.</summary>
    public static readonly string[] Todos = [Critico, Riesgo, Seguimiento, Normal, SinBase];

    public static string Etiqueta(string estado) => estado switch
    {
        Critico => "Crítico",
        Riesgo => "En riesgo",
        Seguimiento => "En seguimiento",
        Normal => "Normal",
        _ => "Sin comparación",
    };

    /// <summary>El estado por % de caída. Sin ventas el año anterior, no hay con qué comparar.</summary>
    public static string Clasificar(decimal actual, decimal anterior)
    {
        if (anterior <= 0) return SinBase;

        var caida = (anterior - actual) / anterior * 100m;
        if (caida >= 71m) return Critico;
        if (caida >= 26m) return Riesgo;
        if (caida >= 11m) return Seguimiento;
        return Normal;
    }

    /// <summary>La caída en %: positiva si compra menos que antes. Nula si el año anterior no compró.</summary>
    public static decimal? CaidaPct(decimal actual, decimal anterior) =>
        anterior > 0 ? Math.Round((anterior - actual) / anterior * 100m, 1) : null;
}

/// <summary>
/// Dos tramos del mismo largo, uno por año: lo que se mide y contra qué. Sin fechas, del 1 de enero a hoy contra el
/// mismo tramo del año anterior.
/// </summary>
public sealed record PeriodoComparado(DateTime Desde, DateTime Hasta, DateTime AnteriorDesde, DateTime AnteriorHasta)
{
    /// <summary>Un tramo más largo que esto es pedir el sistema entero de golpe.</summary>
    private const int MaxDias = 800;

    public static PeriodoComparado Crear(DateTime? desde, DateTime? hasta, DateTime hoy)
    {
        // Un día es un día: sin hora ni zona, para que viaje como "2026-10-27T00:00:00" y no se corra al día anterior.
        static DateTime Dia(DateTime d) => new(d.Year, d.Month, d.Day);

        var fin = Dia(hasta ?? hoy);
        var ini = Dia(desde ?? new DateTime(fin.Year, 1, 1));

        if (ini > fin)
            throw new Exceptions.BadRequestException("El \"desde\" no puede ser después del \"hasta\".");
        if ((fin - ini).TotalDays > MaxDias)
            throw new Exceptions.BadRequestException($"Elige un rango de hasta {MaxDias} días.");

        return new PeriodoComparado(ini, fin, AUnAnioAntes(ini), AUnAnioAntes(fin));
    }

    /// <summary>La misma fecha un año antes; el 29 de febrero cae en el 28 si el año anterior no fue bisiesto.</summary>
    private static DateTime AUnAnioAntes(DateTime dia) =>
        new(dia.Year - 1, dia.Month, Math.Min(dia.Day, DateTime.DaysInMonth(dia.Year - 1, dia.Month)));

    // Los límites en UTC para consultar: desde el inicio del primer día hasta antes del día siguiente al último.
    public DateTime ActualIni => Zona.AUtc(Desde);
    public DateTime ActualFin => Zona.AUtc(Hasta.AddDays(1));
    public DateTime AnteriorIni => Zona.AUtc(AnteriorDesde);
    public DateTime AnteriorFin => Zona.AUtc(AnteriorHasta.AddDays(1));
}
