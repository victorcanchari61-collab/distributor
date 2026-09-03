namespace Backend.Dtos.Requests;

public abstract class AlmacenRequestBase
{
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }
}

public class CreateAlmacenRequest : AlmacenRequestBase;

public class UpdateAlmacenRequest : AlmacenRequestBase
{
    public bool Activo { get; set; } = true;
}

public abstract class MotivoRequestBase
{
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;

    /// <summary>ENTRADA o SALIDA.</summary>
    public string Tipo { get; set; } = string.Empty;
}

public class CreateMotivoRequest : MotivoRequestBase;

public class UpdateMotivoRequest : MotivoRequestBase
{
    public bool Activo { get; set; } = true;
}

/// <summary>Una línea del ajuste.</summary>
public class LineaAjusteRequest
{
    public int ProductoId { get; set; }

    /// <summary>En qué presentación se cuenta. Vacío significa unidad base.</summary>
    public int? PresentacionId { get; set; }

    /// <summary>Cuántas presentaciones. Siempre positiva: el signo lo da el motivo.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>
    /// Lo que costó UNA presentación completa: el saco entero, no el kilo.
    /// Solo se usa en motivos de entrada; en las salidas el costo lo hereda
    /// del stock que sale.
    /// </summary>
    public decimal? CostoPresentacion { get; set; }

    /// <summary>Solo en motivos de entrada: el lote del proveedor, si lo trae.</summary>
    public string? Lote { get; set; }

    /// <summary>Solo en motivos de entrada: cuándo vence, si aplica.</summary>
    public DateTime? FechaVencimiento { get; set; }
}

/// <summary>Ajuste de inventario: el documento formal con su motivo.</summary>
public class CrearAjusteRequest
{
    public int AlmacenId { get; set; }
    public int MotivoId { get; set; }
    public DateTime? Fecha { get; set; }
    public string? Observacion { get; set; }

    /// <summary>Flete o gastos de toda la entrada, repartidos entre las líneas.</summary>
    public decimal Flete { get; set; }

    public List<LineaAjusteRequest> Detalle { get; set; } = [];
}

/// <summary>Una línea de una transferencia. Sin costo: se hereda del que sale.</summary>
public class LineaTransferenciaRequest
{
    public int ProductoId { get; set; }
    public int? PresentacionId { get; set; }
    public decimal Cantidad { get; set; }
}

/// <summary>Transferencia entre dos almacenes propios. El costo viaja con la mercadería.</summary>
public class CrearTransferenciaRequest
{
    public int AlmacenOrigenId { get; set; }
    public int AlmacenDestinoId { get; set; }
    public DateTime? Fecha { get; set; }
    public string? Observacion { get; set; }
    public List<LineaTransferenciaRequest> Detalle { get; set; } = [];
}

/// <summary>Una línea de un préstamo.</summary>
public class LineaPrestamoRequest
{
    public int ProductoId { get; set; }
    public int? PresentacionId { get; set; }
    public decimal Cantidad { get; set; }

    /// <summary>
    /// Solo para préstamos RECIBIDOS: lo que vale una presentación completa,
    /// si no quieres usar el costo de referencia del producto.
    /// </summary>
    public decimal? CostoPresentacion { get; set; }
}

/// <summary>
/// Mercadería que sale o entra desde fuera de la empresa: se presta y se
/// espera de vuelta.
/// </summary>
public class CrearPrestamoRequest
{
    /// <summary>DADO o RECIBIDO.</summary>
    public string Tipo { get; set; } = string.Empty;

    public string Contraparte { get; set; } = string.Empty;
    public int AlmacenId { get; set; }
    public DateTime? Fecha { get; set; }
    public string? Observacion { get; set; }
    public List<LineaPrestamoRequest> Detalle { get; set; } = [];
}

/// <summary>Cuánto se devuelve de una línea del préstamo, en unidad base.</summary>
public class LineaDevolucionPrestamoRequest
{
    public int PrestamoDetalleId { get; set; }
    public decimal Cantidad { get; set; }
}

public class DevolverPrestamoRequest
{
    public List<LineaDevolucionPrestamoRequest> Detalle { get; set; } = [];
}
