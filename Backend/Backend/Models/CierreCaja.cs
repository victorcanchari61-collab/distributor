namespace Backend.Models;

/// <summary>
/// El cierre de la caja de un vendedor o repartidor: cuenta lo que tiene de
/// verdad y entrega eso a otra cuenta (la caja del dueño, un banco).
///
/// Lo que no entregó queda en su caja: si faltó plata, el saldo que le queda
/// es justo lo que debe; si sobró, queda en negativo.
/// </summary>
public class CierreCaja
{
    public int Id { get; set; }

    /// <summary>La caja que se cierra.</summary>
    public int CuentaFinancieraId { get; set; }
    public CuentaFinanciera? CuentaFinanciera { get; set; }

    /// <summary>Quién cierra: el responsable de esa caja.</summary>
    public int UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    /// <summary>Lo que la caja decía tener al cerrar: lo que debería haber entregado.</summary>
    public decimal SaldoSistema { get; set; }

    public decimal Billetes { get; set; }
    public decimal Monedas { get; set; }

    public decimal Contado => Billetes + Monedas;

    /// <summary>Negativa: faltó plata. Positiva: sobró.</summary>
    public decimal Diferencia => Contado - SaldoSistema;

    /// <summary>A qué cuenta se entregó lo contado.</summary>
    public int CuentaDestinoId { get; set; }
    public CuentaFinanciera? CuentaDestino { get; set; }

    /// <summary>Las dos mitades de la entrega. Nulas si no se contó nada.</summary>
    public int? MovimientoSalidaId { get; set; }
    public int? MovimientoEntradaId { get; set; }

    public string? Observacion { get; set; }
}
