namespace Backend.Dtos.Requests;

/// <summary>Una línea de un pedido o de una nota de venta.</summary>
public class LineaVentaRequest
{
    /// <summary>
    /// El id de la línea existente que se está cambiando. Vacío o 0 es una
    /// línea nueva.
    ///
    /// En una nota de venta es además lo que ata la línea a su devolución: por
    /// él se sabe que bajó de cantidad, y una línea que deja de venir es una
    /// que se devuelve entera.
    /// </summary>
    public int? Id { get; set; }

    public int ProductoId { get; set; }

    /// <summary>En qué presentación se vende. Vacío significa unidad base.</summary>
    public int? PresentacionId { get; set; }

    /// <summary>Cuántas presentaciones.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Precio de venta de UNA presentación completa: la caja entera, no la unidad.</summary>
    public decimal PrecioUnitario { get; set; }

    /// <summary>
    /// Solo al editar un pedido: si esta línea existente se quitó. Nunca se
    /// borra de la base — queda anulada para conservar su historial.
    /// </summary>
    public bool Anulado { get; set; }
}

/// <summary>Lo que pide un cliente: cabecera + líneas.</summary>
public class CrearPedidoRequest
{
    public int ClienteId { get; set; }
    public int? ListaPrecioId { get; set; }
    public DateTime? Fecha { get; set; }
    public string? Observacion { get; set; }

    /// <summary>CONTADO o CREDITO: en qué quedaron con el cliente. Vacío usa CONTADO.</summary>
    public string? CondicionPago { get; set; }

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
    /// <summary>
    /// De dónde sale la mercadería.
    ///
    /// Opcional cuando el pedido reservó stock: ahí ya está apartada en un
    /// almacén concreto y sale de ese. Mandar otro dejaría la reserva colgada
    /// en el primero y descontaría de donde nadie aparto nada.
    /// </summary>
    public int? AlmacenId { get; set; }

    /// <summary>
    /// Lo que de verdad se entregó, cuando no fue todo lo pedido.
    ///
    /// Solo van las líneas que cambian: una que no aparece se entregó completa.
    /// La venta lleva —y cobra— únicamente lo entregado, y cada recorte queda
    /// registrado como novedad con su motivo.
    /// </summary>
    public List<LineaEntregaRequest> Lineas { get; set; } = [];
}

/// <summary>Cuánto de una línea del pedido se entregó, y por qué no fue todo.</summary>
public class LineaEntregaRequest
{
    public int PedidoDetalleId { get; set; }

    /// <summary>
    /// Lo entregado, en unidad base: 9 cajas de 12 y 5 sueltas son 113. Cero
    /// quita el producto de la venta. Más de lo pedido no vale: eso es otro pedido.
    /// </summary>
    public decimal Cantidad { get; set; }

    /// <summary>Obligatorio cuando se entrega menos de lo pedido.</summary>
    public int? MotivoId { get; set; }

    public string? Observacion { get; set; }
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
