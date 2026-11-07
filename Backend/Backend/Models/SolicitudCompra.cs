namespace Backend.Models;

/// <summary>Estado de una solicitud de compra.</summary>
public static class EstadoSolicitudCompra
{
    /// <summary>
    /// Se está armando: solo la ve quien la pidió y nadie la atiende todavía. Se va completando (hoy un producto,
    /// mañana otro) y recién cuando está lista se envía al administrador.
    /// </summary>
    public const string Borrador = "BORRADOR";

    /// <summary>Ya se envió: espera que el administrador la atienda. Quien la pidió todavía puede corregirla o anularla.</summary>
    public const string Pendiente = "PENDIENTE";

    /// <summary>Compras ya hizo con ella una orden de compra (ver <see cref="OrdenCompra.SolicitudCompraId"/>).</summary>
    public const string Atendida = "ATENDIDA";

    /// <summary>Compras la rechazó, con un motivo que ve quien la pidió.</summary>
    public const string Rechazada = "RECHAZADA";

    /// <summary>Quien la pidió la retiró antes de que se atendiera.</summary>
    public const string Anulada = "ANULADA";
}

/// <summary>Qué tan rápido hace falta lo que se pide.</summary>
public static class UrgenciaSolicitudCompra
{
    public const string Normal = "NORMAL";
    public const string Urgente = "URGENTE";

    public static readonly string[] Todas = [Normal, Urgente];
}

/// <summary>
/// Lo que el almacén pide que se compre: un documento INTERNO, que todavía no es un compromiso con ningún
/// proveedor.
///
/// El almacenero ve el stock pero no compra: pide aquí lo que hace falta y Compras decide. De una solicitud
/// nace la <see cref="OrdenCompra"/> —con proveedor y costos, que el almacenero no maneja—, y esa orden es la
/// que se le envía al proveedor. Por eso la solicitud no lleva costos ni proveedor.
/// </summary>
public class SolicitudCompra
{
    public int Id { get; set; }

    /// <summary>Correlativo visible: SC-0001.</summary>
    public string Numero { get; set; } = string.Empty;

    /// <summary>Para qué almacén se pide (a dónde va a llegar la mercadería).</summary>
    public int AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    public string Urgencia { get; set; } = UrgenciaSolicitudCompra.Normal;
    public string Estado { get; set; } = EstadoSolicitudCompra.Pendiente;

    /// <summary>Para qué se pide: "se acaba el aceite", "pedido grande del lunes".</summary>
    public string? Observacion { get; set; }

    /// <summary>Por qué Compras la rechazó. Solo cuando está <see cref="EstadoSolicitudCompra.Rechazada"/>.</summary>
    public string? MotivoRechazo { get; set; }

    /// <summary>Quién la pidió.</summary>
    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Cuándo Compras la respondió: al rechazarla o al hacer con ella la orden de compra. Sirve para avisarle a quien
    /// la pidió y para que ese aviso se apague solo con los días.
    /// </summary>
    public DateTime? FechaRespuesta { get; set; }

    public List<SolicitudCompraDetalle> Detalle { get; set; } = [];
}

/// <summary>Un producto pedido, en la presentación y cantidad que escribió quien lo pide.</summary>
public class SolicitudCompraDetalle
{
    public int Id { get; set; }

    public int SolicitudCompraId { get; set; }
    public SolicitudCompra? SolicitudCompra { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int? PresentacionId { get; set; }
    public ProductoPresentacion? Presentacion { get; set; }

    /// <summary>Cuántas presentaciones, tal como se escribió: "10 Saco 50 kg".</summary>
    public decimal CantidadPresentacion { get; set; }

    /// <summary>La misma cantidad en unidad base.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Una aclaración de la línea: "de la marca de siempre", "solo si baja el precio".</summary>
    public string? Nota { get; set; }
}
