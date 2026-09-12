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

    public int RutaId { get; set; }
    public Ruta? Ruta { get; set; }

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

/// <summary>Un pedido cargado en el camión.</summary>
public class DespachoDetalle
{
    public int Id { get; set; }

    public int DespachoId { get; set; }
    public Despacho? Despacho { get; set; }

    public int PedidoId { get; set; }
    public Pedido? Pedido { get; set; }
}
