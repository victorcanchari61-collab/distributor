namespace Backend.Models;

/// <summary>
/// Un día no laborable. No hay calendario oficial cargado: cada negocio
/// decide a mano cuáles feriados aplican. Quien trabaja un feriado cobra ese
/// día doble en la planilla.
/// </summary>
public class Feriado
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
