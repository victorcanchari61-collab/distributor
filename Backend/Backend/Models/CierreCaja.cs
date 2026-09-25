namespace Backend.Models;

/// <summary>
/// El cierre de la caja de un vendedor o repartidor: cuenta lo que tiene de
/// verdad y entrega eso a otra cuenta (la caja del dueño, un banco).
///
/// La caja siempre queda en cero: si faltó plata, la diferencia sale como
/// faltante y se le descuenta en su planilla; si sobró, entra como sobrante.
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

    /// <summary>El faltante o sobrante que deja la caja en cero. Nulo si cuadró exacto.</summary>
    public int? MovimientoAjusteId { get; set; }

    public string? Observacion { get; set; }

    /// <summary>Se registró mal (error de conteo): sus movimientos se reversaron.</summary>
    public bool Anulado { get; set; }

    public DescuentoFaltante? Descuento { get; set; }
}

public static class EstadoDescuentoFaltante
{
    /// <summary>Todavía le falta descontar algo (o todo).</summary>
    public const string Pendiente = "PENDIENTE";

    /// <summary>Ya se le descontó completo en una o más planillas pagadas.</summary>
    public const string Descontado = "DESCONTADO";

    /// <summary>Se anuló el cierre que lo originó.</summary>
    public const string Anulado = "ANULADO";
}

/// <summary>
/// Lo que un trabajador debe por un faltante de caja. Se le descuenta en la
/// planilla semanal; si no alcanza lo que cobra esa semana, el resto queda
/// pendiente para la siguiente.
/// </summary>
public class DescuentoFaltante
{
    public int Id { get; set; }

    public int CierreCajaId { get; set; }
    public CierreCaja? CierreCaja { get; set; }

    /// <summary>De quién es la deuda: el usuario de la caja. Su empleado se resuelve al armar la planilla.</summary>
    public int UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public decimal Monto { get; set; }

    /// <summary>Cuánto ya se descontó en planillas pagadas.</summary>
    public decimal MontoAplicado { get; set; }

    public decimal Saldo => Monto - MontoAplicado;

    public string Estado { get; set; } = EstadoDescuentoFaltante.Pendiente;
}
