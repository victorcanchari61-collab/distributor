namespace Backend.Models;

/// <summary>
/// El cierre de caja de un día: cuánto efectivo debería haber (lo cobrado
/// menos lo pagado en efectivo, según los documentos del día) contra cuánto
/// se contó de verdad. Solo importa el efectivo — una transferencia o una
/// billetera digital no se cuenta a mano, así que no hay nada que arquear ahí.
///
/// Uno por día: registrarlo de nuevo el mismo día reemplaza el anterior, para
/// que un conteo corregido no deje dos cierres del mismo día compitiendo.
/// </summary>
public class ArqueoCaja
{
    public int Id { get; set; }

    /// <summary>El día que se arquea (solo la fecha; la hora no importa).</summary>
    public DateTime Fecha { get; set; }

    /// <summary>Lo que deberían haber en caja según los documentos, congelado al momento de cerrar.</summary>
    public decimal MontoEsperado { get; set; }

    /// <summary>Lo que se contó físicamente.</summary>
    public decimal MontoContado { get; set; }

    public string? Observacion { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
