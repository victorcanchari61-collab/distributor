namespace Backend.Models;

public static class EstadoDevolucion
{
    /// <summary>Registrada y a la espera. Todavía no mueve stock ni dinero.</summary>
    public const string Solicitada = "SOLICITADA";

    /// <summary>Aceptada: la mercadería entró y la venta bajó de importe.</summary>
    public const string Aprobada = "APROBADA";

    /// <summary>No se acepta. Queda con su motivo, sin tocar nada.</summary>
    public const string Rechazada = "RECHAZADA";
}

/// <summary>
/// Lo que un cliente devuelve de una venta.
///
/// Nace SIEMPRE de una nota de venta y es parcial: se devuelven algunas
/// líneas y algunas cantidades. Devolver todo es otra cosa — eso es anular la
/// venta —, y por eso esto no reemplaza a la anulación.
///
/// Nace Solicitada y NO mueve nada. Solo al aprobarla entra la mercadería y
/// baja la deuda: quien la recibe en la calle no es quien decide aceptarla, y
/// entre una cosa y la otra pasan horas.
/// </summary>
public class Devolucion
{
    public int Id { get; set; }

    /// <summary>Correlativo visible: DV-0001.</summary>
    public string Numero { get; set; } = string.Empty;

    public int NotaVentaId { get; set; }
    public NotaVenta? NotaVenta { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    public string Estado { get; set; } = EstadoDevolucion.Solicitada;

    /// <summary>Por qué la devuelve: producto en mal estado, error en el pedido...</summary>
    public string? Motivo { get; set; }

    public string? Observacion { get; set; }

    /// <summary>
    /// A qué almacén vuelve la mercadería.
    ///
    /// Se pide aparte y no se hereda de la venta: lo que sale del camión suele
    /// volver al depósito que tenga sitio, no necesariamente al que despachó.
    /// </summary>
    public int AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    /// <summary>Quién la registró.</summary>
    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public int? AprobadoPorId { get; set; }
    public Usuario? AprobadoPor { get; set; }
    public DateTime? ResueltaEn { get; set; }

    /// <summary>Por qué se rechazó. Sin esto, un rechazo no se puede explicar.</summary>
    public string? MotivoRechazo { get; set; }

    /// <summary>El movimiento de inventario que generó al aprobarse.</summary>
    public int? DocumentoInventarioId { get; set; }
    public DocumentoInventario? DocumentoInventario { get; set; }

    public ICollection<DevolucionDetalle> Detalle { get; set; } = [];
}

/// <summary>Una línea devuelta, atada a la línea de la venta de la que salió.</summary>
public class DevolucionDetalle
{
    public int Id { get; set; }

    public int DevolucionId { get; set; }
    public Devolucion? Devolucion { get; set; }

    /// <summary>
    /// La línea de la venta que se devuelve.
    ///
    /// Atada a la línea y no solo al producto: es lo que permite reponer la
    /// mercadería a las MISMAS capas de costo de las que salió, y comprobar
    /// que no se devuelva más de lo que se vendió.
    /// </summary>
    public int NotaVentaDetalleId { get; set; }
    public NotaVentaDetalle? NotaVentaDetalle { get; set; }

    /// <summary>Cuántas presentaciones vuelven.</summary>
    public decimal CantidadPresentacion { get; set; }

    /// <summary>Lo mismo en unidad base, que es como se mueve el stock.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>El precio al que se vendió: es lo que se le descuenta al cliente.</summary>
    public decimal PrecioUnitario { get; set; }

    /// <summary>
    /// Si vuelve a estar disponible para vender.
    ///
    /// Lo roto o vencido entra igual —para que el costo vuelva y quede el
    /// rastro— y sale en el acto como merma. Si no entrara, la mercadería
    /// desaparecería del sistema sin que nadie pueda explicar dónde fue.
    /// </summary>
    public bool ReingresaStock { get; set; } = true;

    public decimal Importe => Cantidad * PrecioUnitario;
}
