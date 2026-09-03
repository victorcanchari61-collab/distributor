namespace Backend.Dtos.Responses;

public class AlmacenResponse
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }
    public bool EsPrincipal { get; set; }
    public bool Activo { get; set; }

    /// <summary>Cuántos productos tienen stock ahí.</summary>
    public int Productos { get; set; }

    /// <summary>Cuánto vale la mercadería que guarda, al costo.</summary>
    public decimal Valorizado { get; set; }
}

public class MotivoResponse
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;

    /// <summary>ENTRADA o SALIDA.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>Del sistema: no se elige a mano, no se edita ni se elimina.</summary>
    public bool DelSistema { get; set; }

    /// <summary>Si al usarlo hay que declarar el costo.</summary>
    public bool PideCosto { get; set; }

    public bool Activo { get; set; }

    /// <summary>Cuántos movimientos lo usan.</summary>
    public int Movimientos { get; set; }
}

/// <summary>Stock de un producto en un almacén.</summary>
public class StockResponse
{
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string? Categoria { get; set; }
    public string? Marca { get; set; }
    public string UnidadBase { get; set; } = string.Empty;

    public int AlmacenId { get; set; }
    public string Almacen { get; set; } = string.Empty;

    public decimal Stock { get; set; }
    public decimal StockMinimo { get; set; }

    /// <summary>Debajo del mínimo: hay que reponer.</summary>
    public bool BajoMinimo { get; set; }

    /// <summary>Costo de la capa más antigua: la que se consume ahora.</summary>
    public decimal? CostoActual { get; set; }
    public decimal? CostoUltimo { get; set; }
    public decimal Valorizado { get; set; }

    public List<CapaResponse> Capas { get; set; } = [];
}

public class CapaResponse
{
    public int Id { get; set; }
    public decimal CantidadInicial { get; set; }
    public decimal CantidadDisponible { get; set; }
    public decimal CostoUnitario { get; set; }
    public decimal Valor { get; set; }
    public string Origen { get; set; } = string.Empty;
    public string? Lote { get; set; }
    public DateTime? FechaVencimiento { get; set; }
    public DateTime Fecha { get; set; }
}

/// <summary>Una capa con stock, vista desde "qué vence pronto" en vez de "qué tiene un producto".</summary>
public class LoteResponse
{
    public int CapaId { get; set; }
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;
    public int AlmacenId { get; set; }
    public string Almacen { get; set; } = string.Empty;
    public string? Lote { get; set; }
    public DateTime? FechaVencimiento { get; set; }

    /// <summary>Negativo si ya venció. Null si no tiene fecha de vencimiento.</summary>
    public int? DiasParaVencer { get; set; }

    public decimal CantidadDisponible { get; set; }
    public decimal CostoUnitario { get; set; }
    public decimal Valor { get; set; }
}

/// <summary>Una línea del kardex, con el saldo que dejó.</summary>
public class KardexResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }
    public string Documento { get; set; } = string.Empty;
    public string Motivo { get; set; } = string.Empty;

    /// <summary>ENTRADA o SALIDA.</summary>
    public string Tipo { get; set; } = string.Empty;

    public int ProductoId { get; set; }
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;
    public string Almacen { get; set; } = string.Empty;

    /// <summary>Cómo se escribió: "2 Saco 50 kg".</summary>
    public string? Presentacion { get; set; }
    public decimal CantidadPresentacion { get; set; }

    /// <summary>En unidad base, siempre positiva.</summary>
    public decimal Cantidad { get; set; }

    public decimal CostoUnitario { get; set; }
    public decimal CostoTotal { get; set; }

    /// <summary>Stock que quedó después de este movimiento.</summary>
    public decimal Saldo { get; set; }

    public bool Anulado { get; set; }
}

public class DocumentoInventarioResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;
    public string Tipo { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }

    public int AlmacenId { get; set; }
    public string Almacen { get; set; } = string.Empty;

    /// <summary>Solo en transferencias: el almacén que recibe.</summary>
    public int? AlmacenDestinoId { get; set; }
    public string? AlmacenDestino { get; set; }

    /// <summary>Solo en recepciones: la compra que se está descargando.</summary>
    public int? CompraId { get; set; }
    public string? Compra { get; set; }

    public int MotivoId { get; set; }
    public string Motivo { get; set; } = string.Empty;
    public string MotivoTipo { get; set; } = string.Empty;

    public string Estado { get; set; } = string.Empty;
    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    /// <summary>Número del documento que lo anuló, si lo hay.</summary>
    public string? AnuladoPor { get; set; }

    public decimal Total { get; set; }
    public int Lineas { get; set; }

    public List<LineaDocumentoResponse> Detalle { get; set; } = [];
}

public class LineaDocumentoResponse
{
    public int Id { get; set; }
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;

    public int? PresentacionId { get; set; }
    public string? Presentacion { get; set; }
    public decimal CantidadPresentacion { get; set; }

    public decimal Cantidad { get; set; }
    public decimal CostoUnitario { get; set; }
    public decimal CostoTotal { get; set; }

    /// <summary>ENTRADA o SALIDA: en una transferencia hay líneas de los dos tipos.</summary>
    public string Tipo { get; set; } = string.Empty;
    public int AlmacenId { get; set; }
    public string Almacen { get; set; } = string.Empty;
}

public class PrestamoResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;

    /// <summary>DADO o RECIBIDO.</summary>
    public string Tipo { get; set; } = string.Empty;

    public string Contraparte { get; set; } = string.Empty;
    public int AlmacenId { get; set; }
    public string Almacen { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }

    /// <summary>PENDIENTE o DEVUELTO.</summary>
    public string Estado { get; set; } = string.Empty;

    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    /// <summary>Cuánto vale, al costo con que se registró.</summary>
    public decimal Total { get; set; }

    public List<PrestamoDetalleResponse> Detalle { get; set; } = [];
}

public class PrestamoDetalleResponse
{
    public int Id { get; set; }
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string UnidadBase { get; set; } = string.Empty;

    public int? PresentacionId { get; set; }
    public string? Presentacion { get; set; }
    public decimal CantidadPresentacion { get; set; }

    public decimal Cantidad { get; set; }
    public decimal CantidadDevuelta { get; set; }

    /// <summary>Cantidad − CantidadDevuelta, en unidad base.</summary>
    public decimal CantidadPendiente { get; set; }

    public decimal CostoUnitario { get; set; }
    public decimal CostoTotal { get; set; }
}
