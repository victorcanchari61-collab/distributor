namespace Backend.Models;

public static class PagoFeriado
{
    public const string Normal = "NORMAL";
    public const string Doble = "DOBLE";
    public const string Triple = "TRIPLE";

    public static readonly string[] Todos = [Normal, Doble, Triple];
}

/// <summary>
/// Un día no laborable o de pago especial. No hay calendario oficial cargado:
/// cada negocio decide a mano cuáles feriados aplican y a qué tarifa se paga.
/// </summary>
public class Feriado
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Pago { get; set; } = PagoFeriado.Normal;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
