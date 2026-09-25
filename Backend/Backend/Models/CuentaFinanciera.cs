namespace Backend.Models;

public static class NaturalezaCuenta
{
    /// <summary>Efectivo físico: hoy solo existe una, la Caja General.</summary>
    public const string Caja = "CAJA";

    /// <summary>Una cuenta bancaria real, con banco/número/CCI.</summary>
    public const string Banco = "BANCO";

    /// <summary>
    /// Una pasarela que retiene fondos antes de liquidarlos al banco (Culqi,
    /// Niubiz...). Solo hace falta si de verdad retiene — si es un reflejo
    /// instantáneo de un banco (como Yape/Plin sin retención), NO es una
    /// cuenta aparte: el método de pago apunta directo al banco.
    /// </summary>
    public const string Pasarela = "PASARELA";

    public static readonly string[] Todas = [Caja, Banco, Pasarela];
}

public static class TipoMovimientoCuenta
{
    public const string Ingreso = "INGRESO";
    public const string Egreso = "EGRESO";
}

/// <summary>
/// De dónde nace un movimiento del libro mayor: qué documento lo generó, para
/// poder rastrearlo de vuelta. Mismo espíritu que el motivo espejo en
/// inventario (ver InventarioService.AnularAsync).
/// </summary>
public static class DocumentoOrigenMovimiento
{
    /// <summary>El dueño entrega efectivo a un vendedor/repartidor para gastos de ruta.</summary>
    public const string AperturaFondoRuta = "APERTURA_FONDO_RUTA";

    /// <summary>Liquidación de un arqueo: lo que el vendedor/repartidor entrega de vuelta.</summary>
    public const string LiquidacionArqueo = "LIQUIDACION_ARQUEO";

    /// <summary>Un ingreso o egreso operativo (planilla, alquiler, aporte de capital, préstamo).</summary>
    public const string MovimientoOperativo = "MOVIMIENTO_OPERATIVO";

    /// <summary>Una de las dos mitades de una transferencia entre cuentas propias.</summary>
    public const string TransferenciaInterna = "TRANSFERENCIA_INTERNA";

    /// <summary>Reversa un movimiento anterior (corrección o anulación).</summary>
    public const string Reversion = "REVERSION";

    /// <summary>Una venta cobrada en efectivo: entra a la caja de quien cobró.</summary>
    public const string PagoVenta = "PAGO_VENTA";

    /// <summary>
    /// El saldo con el que una cuenta bancaria o caja nace al crearla: la
    /// plata que ya tenía antes de empezar a llevarla en el sistema.
    /// </summary>
    public const string SaldoInicial = "SALDO_INICIAL";

    public static readonly string[] Todos =
    [
        AperturaFondoRuta, LiquidacionArqueo, MovimientoOperativo, TransferenciaInterna, Reversion, PagoVenta,
        SaldoInicial,
    ];
}

/// <summary>
/// Un banco como entidad propia (BBVA, BCP, Interbank...): un catálogo simple,
/// sin saldo. Varias CuentaFinanciera (Naturaleza Banco) pueden pertenecer al
/// mismo Banco — el saldo vive en cada cuenta, no aquí.
/// </summary>
public class Banco
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// La entidad que sí tiene saldo real: la Caja General, una cuenta BCP, una
/// cuenta Interbank. Un método de pago (Efectivo, Yape, Transferencia) es solo
/// un canal que apunta a una de estas — nunca tiene saldo propio.
///
/// Ver docs/finanzas-tesoreria.md, sección 0.
/// </summary>
public class CuentaFinanciera
{
    public int Id { get; set; }

    public string Nombre { get; set; } = string.Empty;

    public string Naturaleza { get; set; } = NaturalezaCuenta.Caja;

    /// <summary>
    /// De quién es esta caja, si es la de un vendedor/repartidor (Naturaleza
    /// Caja). Null para la Caja General y para bancos/pasarelas — esas no son
    /// de una persona.
    /// </summary>
    public int? UsuarioResponsableId { get; set; }
    public Usuario? UsuarioResponsable { get; set; }

    /// <summary>A qué Banco pertenece: solo aplica si Naturaleza es Banco.</summary>
    public int? BancoId { get; set; }
    public Banco? Banco { get; set; }

    public string? NumeroCuenta { get; set; }
    public string? Cci { get; set; }
    public string? Titular { get; set; }

    /// <summary>
    /// Cache transaccional: se actualiza junto con cada MovimientoCuenta, igual
    /// que CapaCosto.CantidadDisponible en inventario. La verdad de fondo es la
    /// suma del libro mayor, esto es para no recorrerlo entero en cada consulta.
    /// </summary>
    public decimal SaldoActual { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// El libro mayor real: cada entrada mueve el saldo de una CuentaFinanciera.
/// Se postea desde otros servicios (Arqueo, Gasto operativo...) — no se crea a
/// mano desde una pantalla propia.
/// </summary>
public class MovimientoCuenta
{
    public int Id { get; set; }

    public int CuentaFinancieraId { get; set; }
    public CuentaFinanciera? CuentaFinanciera { get; set; }

    public string Tipo { get; set; } = TipoMovimientoCuenta.Ingreso;
    public decimal Monto { get; set; }

    /// <summary>El saldo de la cuenta justo después de este movimiento.</summary>
    public decimal SaldoResultante { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    public string DocumentoOrigen { get; set; } = string.Empty;

    /// <summary>El id del documento que lo generó (ArqueoCajaId, MovimientoOperativoId...).</summary>
    public int? OrigenId { get; set; }

    /// <summary>Si esto reversa a otro movimiento (corrección o anulación), cuál.</summary>
    public int? MovimientoOrigenId { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public string? Observacion { get; set; }
}

public static class EstadoConciliacion
{
    public const string Pendiente = "PENDIENTE";
    public const string Conciliado = "CONCILIADO";
}

/// <summary>
/// Compara el saldo contable de una cuenta bancaria, a una fecha de corte,
/// contra lo que dice el extracto real. Por saldo total, no línea por línea.
/// </summary>
public class ConciliacionBancaria
{
    public int Id { get; set; }

    public int CuentaFinancieraId { get; set; }
    public CuentaFinanciera? CuentaFinanciera { get; set; }

    /// <summary>Fecha de corte del extracto.</summary>
    public DateTime Fecha { get; set; }

    public decimal SaldoExtracto { get; set; }

    /// <summary>
    /// El saldo del sistema A ESA FECHA (no el de hoy): se reconstruye del
    /// MovimientoCuenta más reciente con Fecha ≤ esta, no de SaldoActual.
    /// </summary>
    public decimal SaldoContable { get; set; }

    public decimal Diferencia => SaldoExtracto - SaldoContable;

    public string? Observacion { get; set; }
    public string Estado { get; set; } = EstadoConciliacion.Pendiente;

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
