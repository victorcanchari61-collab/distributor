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

    // Un día es un día: sin hora ni zona, para que viaje como "2026-10-27T00:00:00" y no se corra al día anterior.
    private static DateTime Dia(DateTime d) => new(d.Year, d.Month, d.Day);

    private static void Validar(DateTime ini, DateTime fin)
    {
        if (ini > fin)
            throw new Exceptions.BadRequestException("El \"desde\" no puede ser después del \"hasta\".");
        if ((fin - ini).TotalDays > MaxDias)
            throw new Exceptions.BadRequestException($"Elige un rango de hasta {MaxDias} días.");
    }

    public static PeriodoComparado Crear(DateTime? desde, DateTime? hasta, DateTime hoy)
    {
        var fin = Dia(hasta ?? hoy);
        var ini = Dia(desde ?? new DateTime(fin.Year, 1, 1));
        Validar(ini, fin);

        return new PeriodoComparado(ini, fin, AUnAnioAntes(ini), AUnAnioAntes(fin));
    }

    /// <summary>
    /// Como <see cref="Crear"/>, pero eligiendo contra qué se compara: el mes anterior (lo normal) o el año anterior.
    /// Sin fechas, del 1 del mes a hoy contra el mismo tramo del mes (o del año) anterior.
    /// </summary>
    public static PeriodoComparado CrearContra(DateTime? desde, DateTime? hasta, DateTime hoy, bool contraAnio)
    {
        var fin = Dia(hasta ?? hoy);
        var ini = Dia(desde ?? new DateTime(fin.Year, fin.Month, 1));
        Validar(ini, fin);

        return contraAnio
            ? new PeriodoComparado(ini, fin, AUnAnioAntes(ini), AUnAnioAntes(fin))
            : new PeriodoComparado(ini, fin, AUnMesAntes(ini), AUnMesAntes(fin));
    }

    /// <summary>La misma fecha un año antes; el 29 de febrero cae en el 28 si el año anterior no fue bisiesto.</summary>
    private static DateTime AUnAnioAntes(DateTime dia) =>
        new(dia.Year - 1, dia.Month, Math.Min(dia.Day, DateTime.DaysInMonth(dia.Year - 1, dia.Month)));

    /// <summary>La misma fecha un mes antes; el 31 cae en el último día del mes anterior si este es más corto.</summary>
    private static DateTime AUnMesAntes(DateTime dia)
    {
        var anterior = dia.AddDays(1 - dia.Day).AddMonths(-1);
        return new DateTime(anterior.Year, anterior.Month, Math.Min(dia.Day, DateTime.DaysInMonth(anterior.Year, anterior.Month)));
    }

    // Los límites en UTC para consultar: desde el inicio del primer día hasta antes del día siguiente al último.
    public DateTime ActualIni => Zona.AUtc(Desde);
    public DateTime ActualFin => Zona.AUtc(Hasta.AddDays(1));
    public DateTime AnteriorIni => Zona.AUtc(AnteriorDesde);
    public DateTime AnteriorFin => Zona.AUtc(AnteriorHasta.AddDays(1));
}
