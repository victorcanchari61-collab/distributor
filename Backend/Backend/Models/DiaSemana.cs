namespace Backend.Models;

/// <summary>
/// Los días en que se visita a un cliente.
///
/// Viven en el código y no en una tabla a propósito: no son un catálogo del
/// negocio — no cambian nunca, nadie añade un octavo y no tienen nada que
/// administrar. Además, para responder "a quién visito hoy" hay que traducir
/// una fecha a día de la semana, y esa traducción vive aquí de todas formas:
/// una tabla añadiría un FK y un join sin quitar una sola línea de código.
///
/// Se guardan en mayúsculas y sin tilde para poder agrupar por día sin que
/// "MIÉRCOLES" y "MIERCOLES" cuenten como dos.
/// </summary>
public static class DiaSemana
{
    public const string Lunes = "LUNES";
    public const string Martes = "MARTES";
    public const string Miercoles = "MIERCOLES";
    public const string Jueves = "JUEVES";
    public const string Viernes = "VIERNES";
    public const string Sabado = "SABADO";
    public const string Domingo = "DOMINGO";

    /// <summary>En orden de semana, que es como se lee en una pantalla.</summary>
    public static readonly string[] Todos =
    [
        Lunes, Martes, Miercoles, Jueves, Viernes, Sabado, Domingo,
    ];

    public static bool EsValido(string dia) => Todos.Contains(dia);

    /// <summary>Pide toda la semana en vez de un día.</summary>
    public const string Semana = "SEMANA";

    /// <summary>
    /// La fecha que le toca a un día de visita en la semana (lunes a domingo) de una fecha de referencia, o la
    /// semana entera con <see cref="Semana"/>. Es lo que permite pedir "los del lunes" y seguir sabiendo a qué
    /// fecha mirar los pedidos para decir cuáles ya se atendieron.
    /// </summary>
    public static (DateTime Desde, DateTime Hasta) DeLaSemana(DateTime referencia, string dia)
    {
        var lunes = referencia.Date.AddDays(-(((int)referencia.DayOfWeek + 6) % 7));
        if (dia == Semana) return (lunes, lunes.AddDays(6));

        var fecha = lunes.AddDays(Array.IndexOf(Todos, dia));
        return (fecha, fecha);
    }

    /// <summary>El día que le toca a una fecha.</summary>
    public static string De(DateTime fecha) => fecha.DayOfWeek switch
    {
        DayOfWeek.Monday => Lunes,
        DayOfWeek.Tuesday => Martes,
        DayOfWeek.Wednesday => Miercoles,
        DayOfWeek.Thursday => Jueves,
        DayOfWeek.Friday => Viernes,
        DayOfWeek.Saturday => Sabado,
        _ => Domingo,
    };

    /// <summary>
    /// Deja el día como se guarda: mayúsculas y sin tilde.
    ///
    /// No decide si vale — de eso se encarga el validador, que es quien puede
    /// devolver un mensaje. Aquí solo se uniforma lo que llega.
    /// </summary>
    public static string? Normalizar(string? dia)
    {
        if (string.IsNullOrWhiteSpace(dia)) return null;

        return dia.Trim().ToUpperInvariant()
            .Replace('Á', 'A').Replace('É', 'E').Replace('Í', 'I')
            .Replace('Ó', 'O').Replace('Ú', 'U');
    }
}
