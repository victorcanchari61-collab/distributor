namespace Backend.Dtos.Responses;

public class LineaVentaResponse
{
    public int Id { get; set; }
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;

    public int? PresentacionId { get; set; }
    public string? Presentacion { get; set; }
    public decimal CantidadPresentacion { get; set; }

    /// <summary>Si el papel imprime esta línea por presentación (ver <c>ProductoPresentacion.PrecioPorPresentacion</c>).</summary>
    public bool PrecioPorPresentacion { get; set; }

    public decimal Cantidad { get; set; }

    /// <summary>Precio por unidad base: derivado, para margenes y reportes.</summary>
    public decimal PrecioUnitario { get; set; }

    /// <summary>Lo que se acordó por cada presentación: S/ 212.50 el saco.</summary>
    public decimal PrecioPresentacion { get; set; }

    public decimal Subtotal { get; set; }

    /// <summary>Si el producto pagaba IGV al momento de esta línea. El precio ya lo incluye.</summary>
    public bool AfectoIgv { get; set; }

    /// <summary>Solo aplica a líneas de pedido: se quitó al editarlo, sin borrarse.</summary>
    public bool Anulado { get; set; }
}

public class PedidoResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public string Cliente { get; set; } = string.Empty;

    /// <summary>La ruta del cliente y el día en que se lo visita: con lo que se filtra el listado.</summary>
    public string? Ruta { get; set; }
    public string? DiaVisita { get; set; }

    public int? ListaPrecioId { get; set; }
    public string? ListaPrecio { get; set; }

    public DateTime Fecha { get; set; }

    /// <summary>PENDIENTE, CONFIRMADO o ANULADO.</summary>
    public string Estado { get; set; } = string.Empty;

    /// <summary>CONTADO o CREDITO: lo que se acordó con el cliente.</summary>
    public string CondicionPago { get; set; } = string.Empty;

    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    public bool ReservaStock { get; set; }
    public int? AlmacenId { get; set; }
    public string? Almacen { get; set; }

    /// <summary>La venta vigente que salió de este pedido, si ya se convirtió.</summary>
    public int? NotaVentaId { get; set; }
    public string? NotaVentaNumero { get; set; }

    /// <summary>
    /// Por qué no se entregó, si el repartidor lo marcó como no entregado.
    /// El pedido sigue Pendiente: puede reintentarse o anularse.
    /// </summary>
    public string? NoEntregadoMotivo { get; set; }
    public string? NoEntregadoObservacion { get; set; }

    public decimal Total { get; set; }
    public List<LineaVentaResponse> Detalle { get; set; } = [];
}

/// <summary>Un pago parcial: un método del catálogo y cuánto se pagó con él.</summary>
public class PagoVentaResponse
{
    public int Id { get; set; }
    public int MetodoPagoId { get; set; }
    public string MetodoPago { get; set; } = string.Empty;
    public decimal Monto { get; set; }
    public DateTime Fecha { get; set; }
    public string? Usuario { get; set; }
    public bool Anulado { get; set; }
}

/// <summary>
/// Un cobro: un pago de una nota de venta, visto desde quién lo cobró en vez
/// de desde el documento. Es la base de "Mis cobros".
/// </summary>
public class CobroResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }

    public int NotaVentaId { get; set; }
    public string NotaVentaNumero { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public string Cliente { get; set; } = string.Empty;

    public int MetodoPagoId { get; set; }
    public string MetodoPago { get; set; } = string.Empty;

    public decimal Monto { get; set; }

    /// <summary>Se anuló después de registrarse: no cuenta para el total cobrado.</summary>
    public bool Anulado { get; set; }
}

public class NotaVentaResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public string Cliente { get; set; } = string.Empty;

    /// <summary>Si nació de confirmar un pedido, cuál. Null si fue directa.</summary>
    public int? PedidoId { get; set; }
    public string? PedidoNumero { get; set; }

    public int AlmacenId { get; set; }
    public string Almacen { get; set; } = string.Empty;

    public DateTime Fecha { get; set; }

    /// <summary>CONFIRMADA o ANULADA.</summary>
    public string Estado { get; set; } = string.Empty;

    /// <summary>CONTADO o CREDITO.</summary>
    public string FormaPago { get; set; } = string.Empty;

    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    /// <summary>
    /// Lo que de verdad se cobra: la suma del Detalle MENOS los Recojos. A
    /// diferencia de una devolución (que ya viene descontada porque encoge
    /// su propia línea), un recojo es de OTRA venta y no tiene línea aquí que
    /// encoger, así que se resta aparte.
    /// </summary>
    public decimal Total { get; set; }
    public List<LineaVentaResponse> Detalle { get; set; } = [];

    /// <summary>
    /// Op. Gravada: lo que se cobra SIN el IGV, de las líneas afectas. El
    /// precio de esas líneas ya lo trae incluido — esto es solo el desglose,
    /// no cambia lo que se cobra.
    /// </summary>
    public decimal OpGravada { get; set; }

    /// <summary>El IGV de las líneas afectas: OpGravada × 18%.</summary>
    public decimal Igv { get; set; }

    /// <summary>
    /// Lo que se cobra por líneas de productos NO afectos a IGV (exonerados).
    /// OpGravada + Igv + OpExonerada = Total.
    /// </summary>
    public decimal OpExonerada { get; set; }

    /// <summary>Con qué se pagó. Puede ser más de un método — un pago mixto.</summary>
    public List<PagoVentaResponse> Pagos { get; set; } = [];

    /// <summary>Suma de Pagos. Si es menor que Total, falta esa diferencia por cobrar.</summary>
    public decimal TotalPagado { get; set; }

    /// <summary>
    /// Lo que el cliente trajo de vuelta de esta venta, ya aprobado.
    ///
    /// NO se le resta a Total: al aprobar la devolución se le baja la cantidad
    /// a la línea, así que Total ya viene descontado. Esto es para poder decir
    /// cuánto se devolvió, y la deuda sigue siendo Total − TotalPagado.
    /// </summary>
    public decimal TotalDevuelto { get; set; }

    /// <summary>
    /// Las devoluciones de esta venta, con su estado.
    ///
    /// Viajan con la venta porque es el unico sitio donde se ven: no se
    /// registran a mano en ninguna pantalla, nacen de editar esta venta y aqui
    /// mismo se aprueban o se rechazan.
    /// </summary>
    public List<DevolucionDeVentaResponse> Devoluciones { get; set; } = [];

    /// <summary>Suma de los Recojos vigentes. Ya está restada de Total; esto es solo informativo.</summary>
    public decimal TotalRecogido { get; set; }

    /// <summary>
    /// Mercadería de OTRA venta que se recogió al entregar esta, y que ya
    /// descontó su valor del Total.
    /// </summary>
    public List<RecojoDeVentaResponse> Recojos { get; set; } = [];
}

/// <summary>Un recojo visto desde su venta.</summary>
public class RecojoDeVentaResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }

    public int ProductoId { get; set; }
    public string Producto { get; set; } = string.Empty;
    public string? Presentacion { get; set; }
    public string UnidadBase { get; set; } = string.Empty;
    public decimal CantidadPresentacion { get; set; }

    /// <summary>Vacío mientras está pendiente: el almacén lo decide quien lo verifica.</summary>
    public int? AlmacenId { get; set; }
    public string? Almacen { get; set; }

    public string Motivo { get; set; } = string.Empty;
    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    public decimal Importe { get; set; }

    /// <summary>PENDIENTE, VERIFICADO o ANULADO.</summary>
    public string Estado { get; set; } = string.Empty;
    public string? VerificadoPor { get; set; }
    public DateTime? VerificadoEn { get; set; }
}

/// <summary>
/// Un recojo pendiente de verificar, visto para la pantalla de Novedades de
/// entrega — con el contexto de la venta que lo descontó, que
/// <see cref="RecojoDeVentaResponse"/> no necesita porque ya está adentro.
/// </summary>
public class RecojoPendienteResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }

    public int NotaVentaId { get; set; }
    public string NotaVenta { get; set; } = string.Empty;
    public string Cliente { get; set; } = string.Empty;

    public int ProductoId { get; set; }
    public string Producto { get; set; } = string.Empty;
    public string? Presentacion { get; set; }
    public string UnidadBase { get; set; } = string.Empty;
    public decimal CantidadPresentacion { get; set; }

    public string Motivo { get; set; } = string.Empty;
    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    public decimal Importe { get; set; }
}

/// <summary>Una devolucion vista desde su venta: lo justo para resolverla.</summary>
public class DevolucionDeVentaResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }

    /// <summary>SOLICITADA, APROBADA o RECHAZADA.</summary>
    public string Estado { get; set; } = string.Empty;

    public string? Motivo { get; set; }
    public string? MotivoRechazo { get; set; }
    public string? Usuario { get; set; }
    public string? AprobadoPor { get; set; }

    public decimal Total { get; set; }
    public List<LineaDevueltaResponse> Detalle { get; set; } = [];
}

/// <summary>Una linea devuelta: que producto y cuanto.</summary>
public class LineaDevueltaResponse
{
    public int NotaVentaDetalleId { get; set; }
    public string Producto { get; set; } = string.Empty;
    public decimal Cantidad { get; set; }
    public string Unidad { get; set; } = string.Empty;
    public decimal Importe { get; set; }
}
