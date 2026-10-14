namespace Backend.Models;

/// <summary>
/// Los cortes de horario del reporte de carga.
///
/// El camión se va llenando durante el día: los clientes aumentan pedidos y
/// entran pedidos nuevos. Para que quien carga sepa QUÉ AGREGAR sin repetir lo
/// que ya subió, el reporte se saca por franjas:
///
///   - Primer corte: los pedidos como quedaron hasta las 15:00. Es la carga base.
///   - Segundo corte: solo lo que se agregó entre las 15:00 y las 17:00.
///   - Tercer corte: solo lo que se agregó de las 17:00 en adelante.
///
/// Los tres suman lo mismo que "todos".
///
/// El día que cuenta es el de los PEDIDOS, no el del reparto: se toma el día del
/// pedido más reciente ANTERIOR al día de reparto (los del lunes para el camión
/// del martes), y todo lo registrado antes (días anteriores incluidos) es base.
///
/// Lo del día de reparto —los aumentos de la mañana y los pedidos nuevos— cae en
/// el tercer corte, que llega hasta que sale el camión. Un pedido nuevo de esa
/// mañana no mueve el día: si lo moviera, todo el camión pasaría a ser "base" y
/// ya no se sabría qué se aumentó. Si el camión sale el mismo día en que se
/// tomaron todos sus pedidos, ese es el día.
/// </summary>
public static class CortesCarga
{
    public const int Todos = 0;
    public const int Primero = 1;
    public const int Segundo = 2;
    public const int Tercero = 3;

    /// <summary>Hasta esta hora del día de carga, lo registrado es la base.</summary>
    public static readonly TimeSpan HoraPrimerCorte = TimeSpan.FromHours(15);

    /// <summary>Entre el primer corte y esta hora, el segundo.</summary>
    public static readonly TimeSpan HoraSegundoCorte = TimeSpan.FromHours(17);

    public static bool EsValido(int corte) => corte is >= Primero and <= Tercero;

    /// <summary>Los cortes 2 y 3 son aumentos: pueden traer bajas, que salen en negativo.</summary>
    public static bool EsAumento(int corte) => corte is Segundo or Tercero;

    /// <summary>Cómo se lee en el selector y en la cabecera del papel.</summary>
    public static string Nombre(int corte) => corte switch
    {
        Primero => "PRIMER CORTE — Pedidos base (00:00 - 15:00 día carga)",
        Segundo => "SEGUNDO CORTE — Aumentos (15:00 - 17:00 día carga)",
        Tercero => "TERCER CORTE — Aumentos (17:00 - 23:59 día carga)",
        _ => "Todos",
    };
}
