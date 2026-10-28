namespace Backend.Models;

/// <summary>Cada cuánto se vuelve a calcular la categoría de los clientes.</summary>
public static class CicloCategorizacion
{
    public const string Mensual = "MENSUAL";
    public const string Trimestral = "TRIMESTRAL";
    public const string Cuatrimestral = "CUATRIMESTRAL";
    public const string Anual = "ANUAL";

    public static readonly string[] Todos = [Mensual, Trimestral, Cuatrimestral, Anual];

    /// <summary>
    /// Meses que dura un ciclo. Los ciclos son de calendario (trimestre = ene-mar, abr-jun...; cuatrimestre =
    /// ene-abr, may-ago, sep-dic), salvo el anual, que es móvil: ver <see cref="Ventana"/>.
    /// </summary>
    public static int Meses(string ciclo) => ciclo switch
    {
        Mensual => 1,
        Trimestral => 3,
        Cuatrimestral => 4,
        _ => 12,
    };

    /// <summary>
    /// Las fechas de un ciclo respecto de un día: el ciclo en el que cae, y el anterior, que es el
    /// que se evalúa.
    ///
    /// La categoría de hoy sale de lo comprado en el ciclo ANTERIOR y rige durante todo el actual:
    /// con ciclo trimestral, un 27 de octubre se evalúa julio-setiembre, rige desde el 1 de octubre
    /// y cambia el 1 de enero. Por eso un mes bueno no sube a nadie a mitad de ciclo.
    /// </summary>
    public static VentanaCiclo Ventana(string ciclo, DateTime dia)
    {
        // El anual no es un año de calendario sino una ventana móvil: se evalúan los doce meses
        // anteriores al mes en curso y el resultado se renueva cada 1.º de mes. Con un año de
        // calendario, quien empieza a comprar en febrero esperaría hasta enero a que se note.
        if (ciclo == Anual)
        {
            var desdeMes = new DateTime(dia.Year, dia.Month, 1);
            return new VentanaCiclo(desdeMes.AddMonths(-12), desdeMes.AddDays(-1), desdeMes, desdeMes.AddMonths(1).AddDays(-1));
        }

        var meses = Meses(ciclo);
        var primerMes = (dia.Month - 1) / meses * meses + 1;

        var vigenteDesde = new DateTime(dia.Year, primerMes, 1);
        var cambiaEl = vigenteDesde.AddMonths(meses);
        var evaluadoDesde = vigenteDesde.AddMonths(-meses);

        return new VentanaCiclo(evaluadoDesde, vigenteDesde.AddDays(-1), vigenteDesde, cambiaEl.AddDays(-1));
    }
}

/// <param name="EvaluadoDesde">Primer día de lo que se evalúa.</param>
/// <param name="EvaluadoHasta">Último día de lo que se evalúa.</param>
/// <param name="VigenteDesde">Desde cuándo rige el resultado.</param>
/// <param name="VigenteHasta">Hasta cuándo rige (el día antes de que cambie).</param>
public sealed record VentanaCiclo(
    DateTime EvaluadoDesde, DateTime EvaluadoHasta, DateTime VigenteDesde, DateTime VigenteHasta);

/// <summary>Los colores que puede tener una categoría: nombres y no códigos, para que cada pantalla los pinte a su manera.</summary>
public static class ColorCategoria
{
    public static readonly string[] Todos = ["sky", "emerald", "amber", "orange", "violet", "slate", "rose"];
}

/// <summary>
/// Una categoría de cliente (Socio, Distribuidor, Mayorista...): un tramo de lo que compró en el
/// ciclo evaluado.
///
/// Solo se guarda dónde EMPIEZA: la categoría de un cliente es la más alta cuyo "desde" no pasa de
/// lo que compró. El "hasta" que se ve en pantalla es el "desde" de la de arriba menos uno; guardar
/// los dos permitiría huecos (un cliente de 34,999.50 sin categoría) o tramos que se pisan.
/// </summary>
public class CategoriaCliente
{
    public int Id { get; set; }

    /// <summary>A, B, C... La A es la más alta. No cambia: es lo que queda guardado en el historial.</summary>
    public string Codigo { get; set; } = string.Empty;

    public string Nombre { get; set; } = string.Empty;
    public string Color { get; set; } = "slate";

    /// <summary>Desde cuántos soles comprados entra en esta categoría. La última es siempre 0.</summary>
    public decimal Desde { get; set; }
}

/// <summary>La configuración general. Hay una sola fila.</summary>
public class ConfiguracionCategorizacion
{
    public int Id { get; set; }
    public string Ciclo { get; set; } = CicloCategorizacion.Trimestral;
    public DateTime ActualizadoEn { get; set; }
    public int? UsuarioId { get; set; }
}

/// <summary>
/// Una vez que se calcularon las categorías: qué se evaluó, desde cuándo rige y cuántos clientes
/// entraron. Es la cabecera de las filas de <see cref="ClienteCategoria"/>.
/// </summary>
public class CalculoCategorizacion
{
    public int Id { get; set; }

    public string Ciclo { get; set; } = CicloCategorizacion.Trimestral;

    public DateTime EvaluadoDesde { get; set; }
    public DateTime EvaluadoHasta { get; set; }
    public DateTime VigenteDesde { get; set; }
    public DateTime VigenteHasta { get; set; }

    public DateTime CalculadoEn { get; set; } = DateTime.UtcNow;

    /// <summary>Lo hizo el proceso diario al cambiar de ciclo, no una persona con "Calcular ahora".</summary>
    public bool Automatico { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public int Clientes { get; set; }
}

/// <summary>
/// La categoría que le tocó a un cliente en un cálculo, con lo que compró.
///
/// Guarda el código y no una relación con la categoría: si después se renombra o se cambian los
/// tramos, el historial sigue diciendo lo que se calculó en su momento.
/// </summary>
public class ClienteCategoria
{
    public int Id { get; set; }

    public int CalculoId { get; set; }
    public CalculoCategorizacion? Calculo { get; set; }

    public int ClienteId { get; set; }
    public Cliente? Cliente { get; set; }

    public string Codigo { get; set; } = string.Empty;

    /// <summary>Lo que compró en el ciclo evaluado (con IGV, sin anuladas y menos recojos).</summary>
    public decimal Monto { get; set; }
}
