namespace Backend.Dtos.Responses;

public class MotivoNovedadResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }

    /// <summary>Salió en el camión y hay que esperarlo de vuelta.</summary>
    public bool RegresaAlAlmacen { get; set; }

    public bool Activo { get; set; }

    /// <summary>En cuántas novedades se usó: si hay alguna, solo se desactiva.</summary>
    public int Usos { get; set; }
}

/// <summary>Lo justo para elegir el motivo al entregar: sin contadores ni los desactivados.</summary>
public class MotivoNovedadOpcionResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
}

/// <summary>Una diferencia entre lo pedido y lo entregado: un producto que quedó corto o sin entregar.</summary>
public class NovedadResponse
{
    public int Id { get; set; }

    /// <summary>LINEA (un producto se entregó en menos) o PEDIDO (no se entregó el pedido entero).</summary>
    public string Tipo { get; set; } = string.Empty;

    public DateTime Fecha { get; set; }

    /// <summary>PENDIENTE, RECIBIDA, FALTANTE, SIN_RETORNO o ANULADA.</summary>
    public string Estado { get; set; } = string.Empty;

    public int PedidoId { get; set; }
    public string Pedido { get; set; } = string.Empty;
    public string Cliente { get; set; } = string.Empty;

    public int? DespachoId { get; set; }
    public string? Despacho { get; set; }

    public int? NotaVentaId { get; set; }
    public string? NotaVenta { get; set; }

    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;

    /// <summary>La presentación en que se pidió: "Caja 12UND". Vacío si se pidió en unidad base.</summary>
    public string? Presentacion { get; set; }

    /// <summary>Unidades base que trae esa presentación.</summary>
    public decimal Factor { get; set; } = 1;
    public string UnidadBase { get; set; } = string.Empty;

    // Todo en unidad base: la pantalla lo parte en cajas y sueltas.
    public decimal CantidadPedida { get; set; }
    public decimal CantidadEntregada { get; set; }
    public decimal CantidadNoEntregada { get; set; }

    /// <summary>Cuánto valen S/ las unidades que no se entregaron.</summary>
    public decimal Importe { get; set; }

    public int MotivoId { get; set; }
    public string Motivo { get; set; } = string.Empty;

    /// <summary>Si la mercadería salió en el camión y hay que esperarla de vuelta.</summary>
    public bool RegresaAlAlmacen { get; set; }

    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    public decimal? CantidadRegresada { get; set; }
    public string? VerificadoPor { get; set; }
    public DateTime? VerificadoEn { get; set; }
    public string? ObservacionVerificacion { get; set; }
}

/// <summary>Contadores del listado completo, sin anuladas.</summary>
public class ResumenNovedadesResponse
{
    public int Total { get; set; }

    /// <summary>Esperando que el encargado cuente lo que volvió.</summary>
    public int PorRevisar { get; set; }

    public int Recibidas { get; set; }
    public int Faltantes { get; set; }

    /// <summary>Cuánto valen S/ todas las unidades no entregadas.</summary>
    public decimal Importe { get; set; }
}
