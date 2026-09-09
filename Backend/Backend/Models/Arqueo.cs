namespace Backend.Models;

public static class EstadoArqueo
{
    public const string Cuadrado = "CUADRADO";

    /// <summary>Se registró mal. No cuenta, pero se conserva con su rastro.</summary>
    public const string Anulado = "ANULADO";
}

/// <summary>
/// En qué se gastó el dinero de la ruta: pasaje, combustible, menú.
///
/// Es catálogo y no una lista fija de campos porque cada distribuidora gasta en
/// cosas distintas, y con campos fijos añadir "peaje" obligaría a migrar la
/// tabla y a tocar las tres capas.
/// </summary>
public class MotivoGasto
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// El cuadre de un día de reparto, de UNA persona.
///
/// Al volver de la ruta, quien cobró declara qué trae: el efectivo, en qué se
/// gastó parte por el camino, y los pagos digitales que le hicieron. El sistema
/// pone enfrente lo que dice que cobró esa persona ese día —las ventas al
/// contado que emitió y los abonos a deudas anteriores— y la diferencia salta
/// sola.
///
/// Es por persona y día, no uno global: en un cierre de toda la caja, un
/// faltante aparece igual pero sin saber de quién, que es justo lo que hay que
/// saber para resolverlo.
/// </summary>
public class ArqueoCaja
{
    public int Id { get; set; }

    /// <summary>El día que se cuadra (solo la fecha; la hora no importa).</summary>
    public DateTime Fecha { get; set; }

    /// <summary>De quién es el cuadre: quien salió a repartir y cobrar.</summary>
    public int UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    // --- Lo que la persona declara ---

    public decimal Billetes { get; set; }
    public decimal Monedas { get; set; }

    // --- Lo que dicen los documentos, congelado al cerrar ---

    /// <summary>Lo que el sistema dice que cobró en efectivo ese día.</summary>
    public decimal EfectivoSistema { get; set; }

    /// <summary>Lo que el sistema dice que le entró por Yape, Plin o transferencia.</summary>
    public decimal BancosSistema { get; set; }

    public string? Observacion { get; set; }

    public string Estado { get; set; } = EstadoArqueo.Cuadrado;

    /// <summary>Quién lo registró, que puede no ser el mismo que cobró.</summary>
    public int? RegistradoPorId { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<ArqueoGasto> Gastos { get; set; } = [];
    public List<ArqueoPagoDigital> PagosDigitales { get; set; } = [];

    /// <summary>
    /// El efectivo que de verdad hubo en la mano: lo que entrega más lo que se
    /// gastó por el camino.
    ///
    /// Los gastos suman y no restan: ese dinero salió de lo cobrado, así que
    /// sin contarlo la ruta siempre parecería tener un faltante del tamaño de
    /// lo que se gastó en combustible.
    /// </summary>
    public decimal TotalEfectivoReal => Billetes + Monedas + Gastos.Sum(g => g.Monto);

    public decimal TotalDigitalReal => PagosDigitales.Sum(p => p.Monto);

    /// <summary>Negativa: falta dinero. Positiva: sobra.</summary>
    public decimal DiferenciaEfectivo => TotalEfectivoReal - EfectivoSistema;

    public decimal DiferenciaBancos => TotalDigitalReal - BancosSistema;

    /// <summary>
    /// Lo que la persona debe: el dinero que el sistema dice que cobró y no
    /// apareció. Es lo que se le descuenta.
    ///
    /// Se suman los faltantes de cada lado por separado, sin dejar que un
    /// sobrante compense: un Yape declarado que nunca llegó al banco es dinero
    /// perdido aunque ese día trajera de más en efectivo, y compensarlos
    /// escondería las dos cosas a la vez.
    /// </summary>
    public decimal Faltante =>
        (DiferenciaEfectivo < 0 ? -DiferenciaEfectivo : 0)
        + (DiferenciaBancos < 0 ? -DiferenciaBancos : 0);

    /// <summary>
    /// Lo que trajo de más. Solo se informa: no se le devuelve ni se le
    /// acumula a favor, porque un sobrante casi siempre es un cobro que se
    /// registró mal, no dinero suyo.
    /// </summary>
    public decimal Sobrante =>
        (DiferenciaEfectivo > 0 ? DiferenciaEfectivo : 0)
        + (DiferenciaBancos > 0 ? DiferenciaBancos : 0);

    /// <summary>
    /// El faltante ya se le descontó o lo repuso.
    ///
    /// Es una marca y no un borrado para que la deuda saldada siga siendo
    /// consultable: "este mes tuvo tres faltantes" es la información que
    /// importa cuando se repite.
    /// </summary>
    public bool FaltanteSaldado { get; set; }

    public DateTime? FechaSaldado { get; set; }
}

/// <summary>Un gasto de la ruta, descontado de lo que se trae.</summary>
public class ArqueoGasto
{
    public int Id { get; set; }

    public int ArqueoCajaId { get; set; }
    public ArqueoCaja? ArqueoCaja { get; set; }

    public int MotivoGastoId { get; set; }
    public MotivoGasto? MotivoGasto { get; set; }

    public decimal Monto { get; set; }

    /// <summary>Para el "otro" del catálogo, y para detallar cualquier gasto.</summary>
    public string? Descripcion { get; set; }
}

/// <summary>
/// Un cobro digital confirmado al cuadrar.
///
/// No se teclea: el sistema ya sabe qué cobró esa persona ese día, así que lo
/// que se hace es recorrer esos cobros y marcar cuáles llegaron de verdad.
/// Pedirle que los escriba de nuevo sería pedirle que los invente, y entonces
/// el cuadre no compara nada.
///
/// Lleva el número de operación porque es lo único que permite después
/// encontrarlo en el estado de cuenta del banco; sin él, un Yape que la
/// persona da por recibido y nunca llegó no se puede rastrear.
/// </summary>
public class ArqueoPagoDigital
{
    public int Id { get; set; }

    public int ArqueoCajaId { get; set; }
    public ArqueoCaja? ArqueoCaja { get; set; }

    /// <summary>
    /// El cobro del sistema que esta línea confirma.
    ///
    /// Nulo solo si ese cobro se borró después: la línea del cuadre se
    /// conserva igual, porque es el rastro de lo que se declaró aquel día.
    /// </summary>
    public int? PagoVentaId { get; set; }
    public PagoVenta? PagoVenta { get; set; }

    /// <summary>De quién vino. Nulo si no se supo identificar al cliente.</summary>
    public int? ClienteId { get; set; }
    public Cliente? Cliente { get; set; }

    public int MetodoPagoId { get; set; }
    public MetodoPago? MetodoPago { get; set; }

    public string? NumeroOperacion { get; set; }

    public decimal Monto { get; set; }
}
