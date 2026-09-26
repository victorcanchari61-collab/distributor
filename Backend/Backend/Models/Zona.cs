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

    /// <summary>Una hora local, vista en UTC: para acotar una consulta por día.</summary>
    public static DateTime AUtc(DateTime local) => local - Peru;

    /// <summary>El día al que pertenece ese instante, en hora local.</summary>
    public static DateTime DiaDe(DateTime utc) => ALocal(utc).Date;

    /// <summary>Hoy, como lo cuenta quien está en la calle.</summary>
    public static DateTime Hoy => DiaDe(DateTime.UtcNow);

    /// <summary>
    /// Un rango de días locales como límites en UTC para una consulta: desde el
    /// inicio del primer día hasta antes del día siguiente al último.
    ///
    /// Sin "hasta" es hoy; sin "desde", los últimos <paramref name="diasPorDefecto"/>
    /// días. Y nunca más de <paramref name="maxDias"/> de una vez: un historial
    /// que crece todos los días no se pide entero.
    /// </summary>
    public static (DateTime Inicio, DateTime Fin) RangoUtc(
        DateTime? desde, DateTime? hasta, int diasPorDefecto = 30, int maxDias = 366)
    {
        var ultimo = (hasta ?? Hoy).Date;
        var primero = (desde ?? ultimo.AddDays(-diasPorDefecto)).Date;
        if (primero > ultimo) (primero, ultimo) = (ultimo, primero);
        if ((ultimo - primero).TotalDays > maxDias) primero = ultimo.AddDays(-maxDias);
        return (AUtc(primero), AUtc(ultimo.AddDays(1)));
    }
}
