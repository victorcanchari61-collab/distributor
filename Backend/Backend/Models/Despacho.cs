namespace Backend.Models;

public static class EstadoDespacho
{
    /// <summary>Se está armando o ya salió: el despacho vale.</summary>
    public const string Armado = "ARMADO";

    /// <summary>Se deshizo. Sus pedidos vuelven a quedar libres para otro.</summary>
    public const string Anulado = "ANULADO";
}

/// <summary>
/// La carga de un camión para un día y una ruta.
///
/// Junta los PEDIDOS — no las ventas — porque así trabaja el negocio: el
/// vendedor toma pedidos en la calle, la oficina arma con ellos el reparto del
/// día, y es el repartidor quien convierte cada pedido en venta al entregarlo.
/// Por eso el despacho no factura ni mueve stock: solo dice qué va en qué
/// camión. El stock sale después, cuando nace la venta.
/// </summary>
public class Despacho
{
    public int Id { get; set; }

    /// <summary>Correlativo visible: DP-0001.</summary>
    public string Numero { get; set; } = string.Empty;

    /// <summary>El día del reparto, que no tiene por qué ser el de hoy.</summary>
    public DateTime Fecha { get; set; } = DateTime.UtcNow.Date;

    /*
     * De qué días son los pedidos que carga el camión.
     *
     * No es la fecha del reparto: lo que sale el lunes se tomó el viernes y se
     * siguió aumentando el sábado mientras se pesaba. Sin este rango, al armar
     * el camión aparecían mezclados todos los pendientes de la ruta —el que
     * quedó colgado del miércoles, el de hoy que es para el próximo— y había
     * que adivinar cuáles iban. Se guarda para que al editar el despacho se
     * vuelva a ver lo mismo.
     */
    public DateTime? PedidosDesde { get; set; }
    public DateTime? PedidosHasta { get; set; }

    /// <summary>
    /// El día de visita que atiende este despacho: LUNES … SABADO.
    ///
    /// Un despacho trabaja UN solo día de visita, como el reporte del sistema anterior (día de visita +
    /// camión → rutas). Es lo que decide qué clientes salen: los que se visitan ese día, de las rutas del
    /// camión. No tiene por qué coincidir con la fecha del reparto. Nulo en los despachos armados antes de que
    /// existiera: esos no filtran por día.
    /// </summary>
    public string? DiaVisita { get; set; }

    /// <summary>
    /// La ruta principal: la primera de <see cref="Rutas"/>.
    ///
    /// Se conserva porque un camión casi siempre recorre varias rutas el mismo día pero el papel, las
    /// listas y todo lo que ya leía este campo necesitan un nombre corto. La lista completa es
    /// <see cref="Rutas"/>.
    /// </summary>
    public int RutaId { get; set; }
    public Ruta? Ruta { get; set; }

    /// <summary>
    /// Todas las rutas que carga este camión ese día: el lunes del camión 1 son las rutas 1 y 7.
    ///
    /// El despacho las junta porque así se reparte de verdad —un camión atiende varias carteras el
    /// mismo día— y con una sola ruta habría que armar dos despachos para el mismo vehículo.
    /// </summary>
    public ICollection<DespachoRuta> Rutas { get; set; } = [];

    public int VehiculoId { get; set; }
    public Vehiculo? Vehiculo { get; set; }

    /// <summary>
    /// Quién maneja ESE día.
    ///
    /// Se guarda aparte del conductor habitual del vehículo: la pantalla lo
    /// propone a partir de él, pero el de un día concreto puede ser otro —
    /// vacaciones, un reemplazo — y el papel del reparto tiene que decir quién
    /// salió de verdad, no quién suele salir.
    /// </summary>
    public int ConductorId { get; set; }
    public Conductor? Conductor { get; set; }

    public string Estado { get; set; } = EstadoDespacho.Armado;

    public string? Observacion { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public ICollection<DespachoDetalle> Detalle { get; set; } = [];
}

/// <summary>Una de las rutas que recorre un despacho.</summary>
public class DespachoRuta
{
    public int Id { get; set; }

    public int DespachoId { get; set; }
    public Despacho? Despacho { get; set; }

    public int RutaId { get; set; }
    public Ruta? Ruta { get; set; }
}

/// <summary>Un pedido cargado en el camión.</summary>
public class DespachoDetalle
{
    public int Id { get; set; }

    public int DespachoId { get; set; }
    public Despacho? Despacho { get; set; }

    public int PedidoId { get; set; }
    public Pedido? Pedido { get; set; }
}
