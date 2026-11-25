namespace Backend.Models;

public static class EstadoDevolucionProveedor
{
    public const string Confirmada = "CONFIRMADA";

    /// <summary>Se deshizo: el stock volvió, la compra quedó como estaba y el saldo a favor que dio se retiró.</summary>
    public const string Anulada = "ANULADA";
}

/// <summary>De dónde sale lo que se devuelve.</summary>
public static class OrigenDevolucionProveedor
{
    /// <summary>Ya había llegado: sale del stock.</summary>
    public const string Recibido = "RECIBIDO";

    /// <summary>Nunca llegó (se rechazó al recibir, o el proveedor no lo trajo): no mueve stock.</summary>
    public const string Pendiente = "PENDIENTE";

    public static readonly string[] Todos = [Recibido, Pendiente];
}

/// <summary>Qué da el proveedor a cambio de lo devuelto.</summary>
public static class ResolucionDevolucionProveedor
{
    /// <summary>
    /// Lo cambia: traerá lo mismo otro día. La plata no se toca y esa cantidad vuelve a quedar por recibir en la
    /// compra, así la reposición se recibe con una recepción normal.
    /// </summary>
    public const string Reposicion = "REPOSICION";

    /// <summary>
    /// No lo repone: la compra baja de total. Primero baja lo que se le debe; si ya se le había pagado de más, lo que
    /// sobra queda como saldo a favor con ese proveedor.
    /// </summary>
    public const string Descuento = "DESCUENTO";

    public static readonly string[] Todas = [Reposicion, Descuento];
}

/// <summary>
/// Lo que se le devuelve a un proveedor de una compra: mercadería que llegó mal, o que nunca llegó.
///
/// Nace SIEMPRE de una compra y es parcial: unas líneas y unas cantidades. Devolver todo lo que no llegó de una compra
/// que no tiene nada recibido es otra cosa —eso es anular la compra—.
///
/// Por cada línea se decide qué da el proveedor a cambio (<see cref="ResolucionDevolucionProveedor"/>): reponerlo otro
/// día o descontarlo. Lo descontado baja la cantidad de la línea de la compra, así que todos los totales de la compra
/// (lo que se debe, los reportes) ya salen con el descuento; lo devuelto queda aquí, con su costo, para el historial.
/// </summary>
public class DevolucionProveedor
{
    public int Id { get; set; }

    /// <summary>Correlativo visible: DVP-0001.</summary>
    public string Numero { get; set; } = string.Empty;

    public int CompraId { get; set; }
    public Compra? Compra { get; set; }

    public int ProveedorId { get; set; }
    public Proveedor? Proveedor { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    public string Estado { get; set; } = EstadoDevolucionProveedor.Confirmada;

    /// <summary>Por qué se devuelve: llegó en mal estado, vencido, no es lo pedido...</summary>
    public string Motivo { get; set; } = string.Empty;

    public string? Observacion { get; set; }

    /// <summary>De qué almacén sale lo que ya había llegado. Null si solo se devolvió lo que no llegó.</summary>
    public int? AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    /// <summary>El documento de inventario con el que salió del stock. Null si no salió nada.</summary>
    public int? DocumentoInventarioId { get; set; }
    public DocumentoInventario? DocumentoInventario { get; set; }

    /// <summary>Cuándo dijo el proveedor que traerá lo que repone. Solo si alguna línea es reposición.</summary>
    public DateTime? FechaReposicion { get; set; }

    /// <summary>La nota de crédito que emite el proveedor por el descuento, si la emite.</summary>
    public string? SerieNotaCredito { get; set; }
    public string? NumeroNotaCredito { get; set; }

    /// <summary>Lo que bajó el total de la compra: las líneas descontadas, a su costo.</summary>
    public decimal MontoDescuento { get; set; }

    /// <summary>
    /// La parte del descuento que ya estaba pagada y quedó como saldo a favor con el proveedor. El resto solo bajó la
    /// deuda.
    /// </summary>
    public decimal SaldoFavorGenerado { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<DevolucionProveedorDetalle> Detalle { get; set; } = [];
}

/// <summary>Una línea devuelta: de qué línea de la compra, cuánto, de dónde sale y qué da el proveedor a cambio.</summary>
public class DevolucionProveedorDetalle
{
    public int Id { get; set; }

    public int DevolucionProveedorId { get; set; }
    public DevolucionProveedor? DevolucionProveedor { get; set; }

    public int CompraDetalleId { get; set; }
    public CompraDetalle? CompraDetalle { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    /// <summary>En unidad base.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>El costo por unidad base de la línea de la compra.</summary>
    public decimal CostoUnitario { get; set; }

    /// <summary>RECIBIDO (sale del stock) o PENDIENTE (nunca llegó).</summary>
    public string Origen { get; set; } = OrigenDevolucionProveedor.Recibido;

    /// <summary>REPOSICION o DESCUENTO.</summary>
    public string Resolucion { get; set; } = ResolucionDevolucionProveedor.Descuento;

    /// <summary>
    /// Cuánto le restó a la cantidad presentada de la línea de la compra ("2 Saco"), para devolvérsela tal cual al
    /// anular. Solo en los descuentos: una reposición no toca la línea.
    /// </summary>
    public decimal CantidadPresentacionDescontada { get; set; }
}

public static class TipoMovimientoSaldoProveedor
{
    /// <summary>Nace de una devolución descontada que ya estaba pagada.</summary>
    public const string Generado = "GENERADO";

    /// <summary>El proveedor devolvió la plata: entra a una caja o banco.</summary>
    public const string Cobrado = "COBRADO";

    /// <summary>Se usó para pagar otra compra del mismo proveedor.</summary>
    public const string Aplicado = "APLICADO";
}

/// <summary>
/// El libro del saldo a favor que se tiene con cada proveedor: lo que él debe devolver.
///
/// Un saldo a favor no se cierra en el momento de la devolución: el proveedor puede devolver la plata ese día, semanas
/// después, en partes, o descontarlo de la próxima compra. Por eso es un libro aparte y no un campo: el saldo de un
/// proveedor es lo Generado menos lo Cobrado y lo Aplicado, sin contar lo anulado.
/// </summary>
public class MovimientoSaldoProveedor
{
    public int Id { get; set; }

    public int ProveedorId { get; set; }
    public Proveedor? Proveedor { get; set; }

    /// <summary>GENERADO, COBRADO o APLICADO.</summary>
    public string Tipo { get; set; } = TipoMovimientoSaldoProveedor.Generado;

    /// <summary>Siempre positivo: el tipo dice si suma o resta.</summary>
    public decimal Monto { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    /// <summary>La devolución que lo generó (GENERADO).</summary>
    public int? DevolucionProveedorId { get; set; }
    public DevolucionProveedor? DevolucionProveedor { get; set; }

    /// <summary>El pago de la compra en la que se usó (APLICADO).</summary>
    public int? CompraPagoId { get; set; }
    public CompraPago? CompraPago { get; set; }

    /// <summary>Con qué devolvió la plata el proveedor (COBRADO).</summary>
    public int? MetodoPagoId { get; set; }
    public MetodoPago? MetodoPago { get; set; }

    /// <summary>El Ingreso con el que entró la plata a la caja o banco (COBRADO).</summary>
    public int? MovimientoCuentaId { get; set; }

    public bool Anulado { get; set; }

    public string? Observacion { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }
}
