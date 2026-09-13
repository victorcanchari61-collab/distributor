namespace Backend.Models;

/// <summary>
/// El día del negocio.
///
/// Todo se guarda en UTC, que es lo correcto para un instante, pero el día al
/// que pertenece un documento es el del reloj de la calle: un pedido tomado a
/// las 8 de la noche en Lima es de ESE día, aunque en UTC ya sea el siguiente.
/// Sin esto, la agenda de visitas de la tarde mostraba la de mañana y los
/// pedidos de la noche contaban para el día equivocado.
/// </summary>
public static class Zona
{
    /// <summary>Perú no tiene horario de verano, así que el desfase es fijo.</summary>
    private static readonly TimeSpan Peru = TimeSpan.FromHours(-5);

    /// <summary>Un instante en UTC, visto desde la hora local.</summary>
    public static DateTime ALocal(DateTime utc) => utc + Peru;

    /// <summary>El día al que pertenece ese instante, en hora local.</summary>
    public static DateTime DiaDe(DateTime utc) => ALocal(utc).Date;

    /// <summary>Hoy, como lo cuenta quien está en la calle.</summary>
    public static DateTime Hoy => DiaDe(DateTime.UtcNow);
}
