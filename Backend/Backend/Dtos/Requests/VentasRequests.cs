namespace Backend.Dtos.Requests;

/// <summary>Una línea de un pedido o de una nota de venta.</summary>
public class LineaVentaRequest
{
    public int ProductoId { get; set; }

    /// <summary>En qué presentación se vende. Vacío significa unidad base.</summary>
    public int? PresentacionId { get; set; }

    /// <summary>Cuántas presentaciones.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Precio de venta de UNA presentación completa: la caja entera, no la unidad.</summary>
    public decimal PrecioUnitario { get; set; }
}

/// <summary>Lo que pide un cliente: cabecera + líneas.</summary>
public class CrearPedidoRequest
{
    public int ClienteId { get; set; }
    public int? ListaPrecioId { get; set; }
    public DateTime? Fecha { get; set; }
    public string? Observacion { get; set; }

    /// <summary>Si aparta stock de <see cref="AlmacenId"/> mientras esté Pendiente.</summary>
    public bool ReservaStock { get; set; }

    /// <summary>Requerido cuando <see cref="ReservaStock"/> es true.</summary>
    public int? AlmacenId { get; set; }

    public List<LineaVentaRequest> Detalle { get; set; } = [];
}

/// <summary>Con qué almacén se despacha el pedido al confirmarlo.</summary>
///
/// <remarks>
/// Un pedido no lleva pagos — eso es cosa de la nota de venta que nace al
/// confirmarlo, y ahí queda sin registrar ninguno (a crédito, pendiente de
/// cobro) hasta que se pague.
/// </remarks>
public class ConfirmarPedidoRequest
{
    public int AlmacenId { get; set; }
}

/// <summary>Un pago parcial: un método del catálogo y cuánto se pagó con él.</summary>
public class PagoVentaRequest
{
    public int MetodoPagoId { get; set; }
    public decimal Monto { get; set; }
}

/// <summary>Una venta directa, sin pedido previo: el stock sale al momento.</summary>
public class CrearNotaVentaRequest
{
    public int ClienteId { get; set; }
    public int AlmacenId { get; set; }
    public int? ListaPrecioId { get; set; }
    public DateTime? Fecha { get; set; }

    /// <summary>CONTADO o CREDITO. Vacío usa CONTADO.</summary>
    public string? FormaPago { get; set; }

    /// <summary>Con qué se paga. Puede traer más de una línea — un pago mixto —, o ninguna si es a crédito.</summary>
    public List<PagoVentaRequest> Pagos { get; set; } = [];

    public string? Observacion { get; set; }
    public List<LineaVentaRequest> Detalle { get; set; } = [];
}
