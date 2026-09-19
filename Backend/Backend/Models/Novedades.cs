namespace Backend.Models;

/// <summary>Cómo se registró la novedad.</summary>
public static class TipoNovedad
{
    /// <summary>
    /// Una línea del pedido se entregó en menos: el cliente recibió 9 cajas
    /// de las 10 que pidió, o ninguna de un producto. El resto del pedido sí
    /// se convirtió en venta.
    /// </summary>
    public const string Linea = "LINEA";

    /// <summary>
    /// El pedido entero no se entregó: no había nadie, cerró, no quiso
    /// recibirlo. No nace ninguna venta y el pedido sigue Pendiente.
    /// </summary>
    public const string Pedido = "PEDIDO";
}

/// <summary>En qué va la revisión de lo que no se entregó.</summary>
public static class EstadoNovedad
{
    /// <summary>
    /// El camión volvió con esa mercadería y nadie la ha contado todavía:
    /// el encargado tiene que decir si llegó o si se perdió por el camino.
    /// </summary>
    public const string Pendiente = "PENDIENTE";

    /// <summary>La mercadería volvió al almacén: se contó y está.</summary>
    public const string Recibida = "RECIBIDA";

    /// <summary>Salió en el camión y no volvió completa: el encargado lo dejó asentado.</summary>
    public const string Faltante = "FALTANTE";

    /// <summary>
    /// El motivo dice que esa mercadería nunca salió del almacén (no se
    /// cargó, no había stock): no hay nada que esperar de vuelta.
    /// </summary>
    public const string SinRetorno = "SIN_RETORNO";

    /// <summary>
    /// Dejó de valer: la venta se anuló, el pedido se anuló o se terminó
    /// entregando. Se conserva para el rastro, pero no cuenta.
    /// </summary>
    public const string Anulada = "ANULADA";
}

/// <summary>
/// Por qué no se entregó algo: "Cliente no quiso", "Producto dañado",
/// "Faltó en el carro".
///
/// Lo crea el dueño y no es una lista fija porque cada negocio pierde
/// entregas por razones distintas, y cada razón se trata distinto después:
/// lo que el cliente rechazó vuelve en el camión y hay que contarlo, lo que
/// no se cargó nunca salió del almacén y no hay nada que revisar.
/// </summary>
public class MotivoNovedad
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }

    /// <summary>
    /// La mercadería salió en el camión y tiene que volver: lo que el
    /// encargado va a esperar y a contar. En falso, nunca salió (se olvidó
    /// cargar, no alcanzó) y no hay nada que verificar al regreso.
    /// </summary>
    public bool RegresaAlAlmacen { get; set; } = true;

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Una diferencia entre lo que el cliente pidió y lo que recibió.
///
/// Es una fila por producto: si un pedido no se entregó completo, hay tantas
/// novedades como líneas quedaron sin entregar. Registra lo que pasó al
/// entregar; qué se hace con esa mercadería después (contarla al volver el
/// camión) lo dice <see cref="Estado"/>.
///
/// El stock NO se toca aquí: solo sale cuando nace la venta y la venta lleva
/// únicamente lo entregado, así que lo no entregado nunca salió del sistema.
/// </summary>
public class NovedadEntrega
{
    public int Id { get; set; }

    /// <summary><see cref="TipoNovedad"/>.</summary>
    public string Tipo { get; set; } = TipoNovedad.Linea;

    public int PedidoId { get; set; }
    public Pedido? Pedido { get; set; }

    /// <summary>La línea del pedido a la que se le recortó. Se conserva aunque el pedido cambie.</summary>
    public int? PedidoDetalleId { get; set; }

    /// <summary>La venta que sí se hizo con lo entregado. Vacía cuando no se entregó nada.</summary>
    public int? NotaVentaId { get; set; }
    public NotaVenta? NotaVenta { get; set; }

    /// <summary>El camión en el que iba el pedido, si iba en uno.</summary>
    public int? DespachoId { get; set; }
    public Despacho? Despacho { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int? PresentacionId { get; set; }
    public ProductoPresentacion? Presentacion { get; set; }

    /// <summary>Lo que pidió el cliente, en unidad base.</summary>
    public decimal CantidadPedida { get; set; }

    /// <summary>Lo que recibió, en unidad base. Cero cuando no se entregó nada.</summary>
    public decimal CantidadEntregada { get; set; }

    /// <summary>Cuánto valen S/ las unidades que no se entregaron, a los precios del pedido.</summary>
    public decimal Importe { get; set; }

    public int MotivoId { get; set; }
    public MotivoNovedad? Motivo { get; set; }

    /// <summary>Lo que el repartidor quiso aclarar.</summary>
    public string? Observacion { get; set; }

    /// <summary>Quién lo registró.</summary>
    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    /// <summary><see cref="EstadoNovedad"/>.</summary>
    public string Estado { get; set; } = EstadoNovedad.Pendiente;

    /// <summary>Cuánto llegó de vuelta al almacén, en unidad base. Lo cuenta el encargado.</summary>
    public decimal? CantidadRegresada { get; set; }

    public int? VerificadoPorId { get; set; }
    public Usuario? VerificadoPor { get; set; }
    public DateTime? VerificadoEn { get; set; }
    public string? ObservacionVerificacion { get; set; }

    /// <summary>Lo que quedó sin entregar.</summary>
    public decimal CantidadNoEntregada => CantidadPedida - CantidadEntregada;
}
