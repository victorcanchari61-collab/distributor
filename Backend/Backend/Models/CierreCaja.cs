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

    /// <summary>Cuántos se contaron de cada billete y moneda. Vacío en los cierres de antes del desglose.</summary>
    public List<CierreCajaDenominacion> Denominaciones { get; set; } = [];
}

/// <summary>Cuántos billetes o monedas de un valor se contaron en un cierre.</summary>
public class CierreCajaDenominacion
{
    public int Id { get; set; }

    public int CierreCajaId { get; set; }
    public CierreCaja? CierreCaja { get; set; }

    /// <summary>200, 0.50... Ver <see cref="Denominacion"/>.</summary>
    public decimal Valor { get; set; }

    public int Cantidad { get; set; }

    public bool EsBillete => Denominacion.EsBillete(Valor);
}

/// <summary>Los billetes y monedas en soles que se cuentan al cerrar caja.</summary>
public static class Denominacion
{
    public static readonly decimal[] Billetes = [200m, 100m, 50m, 20m, 10m];
    public static readonly decimal[] Monedas = [5m, 2m, 1m, 0.5m, 0.2m, 0.1m];
    public static readonly decimal[] Todas = [.. Billetes, .. Monedas];

    /// <summary>De S/ 10 para arriba es billete; lo demás, moneda.</summary>
    public static bool EsBillete(decimal valor) => valor >= 10m;
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
/// Lo que un trabajador debe por un faltante: de su caja al cerrarla, o de un
/// cobro digital que no apareció en el banco. Se le descuenta en la planilla
/// semanal; si no alcanza lo que cobra esa semana, el resto queda pendiente
/// para la siguiente.
///
/// Nace de uno de los dos: <see cref="CierreCajaId"/> o <see cref="PagoVentaId"/>.
/// </summary>
public class DescuentoFaltante
{
    public int Id { get; set; }

    /// <summary>El cierre que dio faltante.</summary>
    public int? CierreCajaId { get; set; }
    public CierreCaja? CierreCaja { get; set; }

    /// <summary>El cobro digital que se rechazó al buscarlo en el banco.</summary>
    public int? PagoVentaId { get; set; }
    public PagoVenta? PagoVenta { get; set; }

    /// <summary>De quién es la deuda: el usuario de la caja. Su empleado se resuelve al armar la planilla.</summary>
    public int UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public decimal Monto { get; set; }

    /// <summary>Cuánto ya se descontó en planillas pagadas.</summary>
    public decimal MontoAplicado { get; set; }

    public decimal Saldo => Monto - MontoAplicado;

    public string Estado { get; set; } = EstadoDescuentoFaltante.Pendiente;
}
