namespace Backend.Models;

/// <summary>Estado de una orden de compra.</summary>
public static class EstadoOrdenCompra
{
    /// <summary>Recién emitida: el proveedor todavía no la aceptó. Se puede editar o anular.</summary>
    public const string Pendiente = "PENDIENTE";

    /// <summary>El proveedor aceptó despacharla. Ya no se edita; generó su Compra.</summary>
    public const string Confirmada = "CONFIRMADA";

    public const string Anulada = "ANULADA";
}

/// <summary>
/// Lo que se le pide al proveedor, antes de que exista compromiso firme.
///
/// Mientras está Pendiente es solo una intención: se puede editar o anular
/// libremente. Confirmarla es aceptar que el proveedor va a despachar, y ese
/// mismo paso crea la <see cref="Compra"/> correspondiente — desde ahí la
/// orden ya no se toca, el seguimiento sigue en la compra.
/// </summary>
public class OrdenCompra
{
    public int Id { get; set; }

    /// <summary>Correlativo visible: OC-000001.</summary>
    public string Numero { get; set; } = string.Empty;

    public int ProveedorId { get; set; }
    public Proveedor? Proveedor { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    /// <summary>Cuándo promete el proveedor entregar.</summary>
    public DateTime? FechaEsperada { get; set; }

    public string Estado { get; set; } = EstadoOrdenCompra.Pendiente;
    public string? Observacion { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<OrdenCompraDetalle> Detalle { get; set; } = [];
}

/// <summary>Un producto pedido dentro de la orden, con el costo pactado.</summary>
public class OrdenCompraDetalle
{
    public int Id { get; set; }

    public int OrdenCompraId { get; set; }
    public OrdenCompra? OrdenCompra { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int? PresentacionId { get; set; }
    public ProductoPresentacion? Presentacion { get; set; }

    /// <summary>Cómo se escribió: "10 Saco 50 kg".</summary>
    public decimal CantidadPresentacion { get; set; }

    /// <summary>En unidad base.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Costo por unidad base, pactado con el proveedor.</summary>
    public decimal CostoUnitario { get; set; }
}

/// <summary>Estado de una compra, de cara a cuánto se recibió.</summary>
public static class EstadoCompra
{
    /// <summary>Nada ha llegado todavía.</summary>
    public const string Pendiente = "PENDIENTE";

    public const string RecibidaParcial = "RECIBIDA_PARCIAL";
    public const string RecibidaTotal = "RECIBIDA_TOTAL";
    public const string Anulada = "ANULADA";
}

/// <summary>Tipo de comprobante que emitió el proveedor por la compra.</summary>
public static class TipoComprobanteCompra
{
    public const string Factura = "FACTURA";
    public const string Boleta = "BOLETA";
    public const string NotaVenta = "NOTA_VENTA";

    public static readonly string[] Todos = [Factura, Boleta, NotaVenta];
}

/// <summary>Cómo se paga la compra al proveedor.</summary>
public static class FormaPagoCompra
{
    public const string Contado = "CONTADO";
    public const string Credito = "CREDITO";

    public static readonly string[] Todas = [Contado, Credito];
}

/// <summary>
/// Una compra lista para recibir: o vino de confirmar una <see cref="OrdenCompra"/>,
/// o se registró directa — una compra al contado, sin negociación previa.
///
/// En ambos casos termina siendo lo mismo: algo que aparece en "Mis compras"
/// esperando que llegue la mercadería, para que Recepciones la vaya
/// descargando (total o parcialmente) contra el motivo del sistema "Compra".
/// </summary>
public class Compra
{
    public int Id { get; set; }

    /// <summary>Correlativo visible: CP-000001.</summary>
    public string Numero { get; set; } = string.Empty;

    public int ProveedorId { get; set; }
    public Proveedor? Proveedor { get; set; }

    /// <summary>Si nació de confirmar una orden, cuál. Null si fue directa.</summary>
    public int? OrdenCompraId { get; set; }
    public OrdenCompra? OrdenCompra { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;
    public string Estado { get; set; } = EstadoCompra.Pendiente;

    /// <summary>El comprobante que trae el proveedor: FACTURA, BOLETA o NOTA_VENTA.</summary>
    public string TipoComprobante { get; set; } = TipoComprobanteCompra.Factura;

    /// <summary>Serie del comprobante del proveedor, ej. "F001". No es nuestro correlativo.</summary>
    public string? SerieComprobante { get; set; }

    /// <summary>Número del comprobante del proveedor, ej. "00000123".</summary>
    public string? NumeroComprobante { get; set; }

    /// <summary>CONTADO o CREDITO.</summary>
    public string FormaPago { get; set; } = FormaPagoCompra.Contado;

    /// <summary>Con qué se pagó: efectivo, transferencia... Opcional.</summary>
    public int? MetodoPagoId { get; set; }
    public MetodoPago? MetodoPago { get; set; }

    public string? Observacion { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<CompraDetalle> Detalle { get; set; } = [];
}

/// <summary>Un producto de la compra, con cuánto ya llegó.</summary>
public class CompraDetalle
{
    public int Id { get; set; }

    public int CompraId { get; set; }
    public Compra? Compra { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int? PresentacionId { get; set; }
    public ProductoPresentacion? Presentacion { get; set; }

    /// <summary>Cómo se escribió: "10 Saco 50 kg".</summary>
    public decimal CantidadPresentacion { get; set; }

    /// <summary>En unidad base. Lo pedido/pactado.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Costo por unidad base: el que crea la capa al recibir.</summary>
    public decimal CostoUnitario { get; set; }

    /// <summary>Cuánto de esta línea ya llegó, en unidad base.</summary>
    public decimal CantidadRecibida { get; set; }
}
