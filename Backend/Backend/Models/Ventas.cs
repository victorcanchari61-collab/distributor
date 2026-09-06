namespace Backend.Models;

/// <summary>Estado de un pedido.</summary>
public static class EstadoPedido
{
    /// <summary>Recién registrado: el cliente todavía no se lo confirmó. Se puede editar o anular.</summary>
    public const string Pendiente = "PENDIENTE";

    /// <summary>Se despachó: ya no se edita; generó su NotaVenta.</summary>
    public const string Confirmado = "CONFIRMADO";

    public const string Anulado = "ANULADO";
}

/// <summary>
/// Lo que pidió un cliente, antes de que exista una venta firme.
///
/// Mientras está Pendiente es solo una intención: se edita o se anula libre.
/// Confirmarlo es despacharlo, y ese mismo paso crea la <see cref="NotaVenta"/>
/// correspondiente — el stock sale ahí, no en el pedido.
/// </summary>
public class Pedido
{
    public int Id { get; set; }

    /// <summary>Correlativo visible: PD-000001.</summary>
    public string Numero { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public Cliente? Cliente { get; set; }

    /// <summary>Con qué lista se cotizó, si se eligió una.</summary>
    public int? ListaPrecioId { get; set; }
    public ListaPrecio? ListaPrecio { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;
    public string Estado { get; set; } = EstadoPedido.Pendiente;
    public string? Observacion { get; set; }

    /// <summary>
    /// Si aparta stock de <see cref="AlmacenId"/> mientras el pedido siga
    /// Pendiente — no mueve nada, solo se resta del disponible que se
    /// muestra en Stock y en los buscadores de producto, para que otro
    /// pedido o venta no prometa lo mismo dos veces. Se libera solo al
    /// confirmar (ahí la NotaVenta ya descuenta el stock real) o al anular.
    /// </summary>
    public bool ReservaStock { get; set; }

    /// <summary>De qué almacén se reserva. Requerido si <see cref="ReservaStock"/>.</summary>
    public int? AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<PedidoDetalle> Detalle { get; set; } = [];
}

/// <summary>Un producto pedido, con el precio cotizado.</summary>
public class PedidoDetalle
{
    public int Id { get; set; }

    public int PedidoId { get; set; }
    public Pedido? Pedido { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int? PresentacionId { get; set; }
    public ProductoPresentacion? Presentacion { get; set; }

    /// <summary>Cómo se escribió: "10 Caja x12".</summary>
    public decimal CantidadPresentacion { get; set; }

    /// <summary>En unidad base.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Precio de venta por unidad base.</summary>
    public decimal PrecioUnitario { get; set; }

    /// <summary>
    /// Se quitó del pedido al editarlo: no cuenta para el total ni se
    /// transfiere a la NotaVenta al confirmar, pero la fila se conserva (no
    /// se borra) para no perder su historial de cambios.
    /// </summary>
    public bool Anulado { get; set; }
}

/// <summary>Cómo se paga una venta al contado.</summary>
public static class FormaPagoVenta
{
    public const string Contado = "CONTADO";
    public const string Credito = "CREDITO";

    public static readonly string[] Todas = [Contado, Credito];
}

/// <summary>
/// Una venta al cliente, lista tal cual: el stock sale al momento de
/// crearla, con el motivo del sistema "Venta" (<see cref="Motivos.Venta"/>).
///
/// No hay estados de "recibido parcial" como en una compra — no tiene sentido
/// una nota de venta a medio despachar, así que anularla revierte el stock
/// entero de una vez.
/// </summary>
public class NotaVenta
{
    public int Id { get; set; }

    /// <summary>Correlativo visible: NV-000001.</summary>
    public string Numero { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public Cliente? Cliente { get; set; }

    /// <summary>Si nació de confirmar un pedido, cuál. Null si fue directa.</summary>
    public int? PedidoId { get; set; }
    public Pedido? Pedido { get; set; }

    public int AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    /// <summary>CONFIRMADA o ANULADA.</summary>
    public string Estado { get; set; } = EstadoNotaVenta.Confirmada;

    /// <summary>CONTADO o CREDITO.</summary>
    public string FormaPago { get; set; } = FormaPagoVenta.Contado;

    public string? Observacion { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    /// <summary>
    /// El documento de inventario que descontó el stock de esta venta. Null
    /// solo si el descuento falló al crearla (queda Anulada sin haber tocado
    /// stock) — así anularla sabe si hay algo que revertir.
    /// </summary>
    public int? DocumentoInventarioId { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<NotaVentaDetalle> Detalle { get; set; } = [];

    /// <summary>Con qué se pagó. Puede ser más de uno — un pago mixto.</summary>
    public List<PagoVenta> Pagos { get; set; } = [];
}

public static class EstadoNotaVenta
{
    public const string Confirmada = "CONFIRMADA";
    public const string Anulada = "ANULADA";
}

/// <summary>Un pago parcial dentro de una nota de venta: un método y cuánto se pagó con él.</summary>
public class PagoVenta
{
    public int Id { get; set; }

    public int NotaVentaId { get; set; }
    public NotaVenta? NotaVenta { get; set; }

    public int MetodoPagoId { get; set; }
    public MetodoPago? MetodoPago { get; set; }

    public decimal Monto { get; set; }

    /// <summary>Cuándo se registró: el de la venta si nació con ella, o el del abono posterior.</summary>
    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    /// <summary>Quién lo cobró. Base de "Mis cobros".</summary>
    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    /// <summary>
    /// Se registró por error: no cuenta para el total cobrado ni para "Mis
    /// cobros", pero se conserva en el historial en vez de borrarse.
    /// </summary>
    public bool Anulado { get; set; }
}

/// <summary>Un producto de la nota de venta. El stock ya salió por esta línea.</summary>
public class NotaVentaDetalle
{
    public int Id { get; set; }

    public int NotaVentaId { get; set; }
    public NotaVenta? NotaVenta { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int? PresentacionId { get; set; }
    public ProductoPresentacion? Presentacion { get; set; }

    /// <summary>Cómo se escribió: "10 Caja x12".</summary>
    public decimal CantidadPresentacion { get; set; }

    /// <summary>En unidad base.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Precio de venta por unidad base.</summary>
    public decimal PrecioUnitario { get; set; }

    /// <summary>
    /// Se quitó de la venta al editarla: no cuenta para el total ni para el
    /// stock que sale, pero la fila se conserva (no se borra) para no perder
    /// su historial de cambios.
    /// </summary>
    public bool Anulado { get; set; }
}
