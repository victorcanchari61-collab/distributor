namespace Backend.Dtos.Responses;

/// <summary>Un pedido dentro del camión, con lo que hace falta para repartirlo.</summary>
public class DespachoPedidoResponse
{
    public int PedidoId { get; set; }
    public string Numero { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public string Cliente { get; set; } = string.Empty;

    /// <summary>DNI, RUC o código del cliente: lo que se lee en la hoja de carga.</summary>
    public string? ClienteDocumento { get; set; }

    /// <summary>Cuándo se tomó el pedido: arma el "del … al …" del reporte.</summary>
    public DateTime Fecha { get; set; }

    /// <summary>Dónde entregarlo: sin esto el papel del reparto no sirve.</summary>
    public string? Direccion { get; set; }
    public string? Mercado { get; set; }
    public string? Telefono { get; set; }

    public decimal Total { get; set; }
    public int Lineas { get; set; }

    /// <summary>La venta, si el repartidor ya lo convirtió.</summary>
    public int? NotaVentaId { get; set; }
    public string? NotaVentaNumero { get; set; }

    /// <summary>
    /// Por qué no se entregó, si el pedido se marcó como no entregado en este
    /// camión. Vacío mientras no se haya marcado o si después se entregó.
    /// </summary>
    public string? NoEntregadoMotivo { get; set; }
    public string? NoEntregadoObservacion { get; set; }

    /// <summary>En cuántos productos se entregó menos de lo pedido.</summary>
    public int LineasConNovedad { get; set; }
}

public class DespachoResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }

    /// <summary>De qué días son los pedidos que se cargaron.</summary>
    public DateTime? PedidosDesde { get; set; }
    public DateTime? PedidosHasta { get; set; }

    public int RutaId { get; set; }
    public string Ruta { get; set; } = string.Empty;

    public int VehiculoId { get; set; }
    /// <summary>La placa, que es como se nombra a un camión de verdad.</summary>
    public string Vehiculo { get; set; } = string.Empty;

    public int ConductorId { get; set; }
    public string Conductor { get; set; } = string.Empty;

    /// <summary>ARMADO o ANULADO.</summary>
    public string Estado { get; set; } = string.Empty;

    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    /// <summary>Cuántos pedidos lleva y cuánto suman.</summary>
    public int Pedidos { get; set; }
    public decimal Total { get; set; }

    /// <summary>Cuántos de esos pedidos ya se convirtieron en venta.</summary>
    public int Entregados { get; set; }

    /// <summary>Cuántos pedidos se marcaron como no entregados.</summary>
    public int NoEntregados { get; set; }

    public List<DespachoPedidoResponse> Detalle { get; set; } = [];
}

/// <summary>
/// Un producto en una presentación, sumado de los pedidos de un mercado.
///
/// Sale sin filtrar ni agrupar más: el reporte de carga lo recorta por mercado y
/// por unidad de medida, y lo junta o lo separa por mercado según se pida.
/// </summary>
public class LineaCargaResponse
{
    /// <summary>0 cuando el cliente no tiene mercado.</summary>
    public int MercadoId { get; set; }
    public string Mercado { get; set; } = string.Empty;

    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;

    public int? PresentacionId { get; set; }
    public string Presentacion { get; set; } = string.Empty;

    /// <summary>Cuántas unidades base trae una presentación: 50 en el saco.</summary>
    public decimal Factor { get; set; }

    /// <summary>La unidad de medida de la presentación: BOL, SAC, UND, KG.</summary>
    public string UnidadCodigo { get; set; } = string.Empty;
    public string UnidadNombre { get; set; } = string.Empty;

    public string UnidadBase { get; set; } = string.Empty;

    public decimal Cantidad { get; set; }
    public decimal EnUnidadBase { get; set; }
}

public class OpcionMercadoCarga
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public int Pedidos { get; set; }
}

public class OpcionUnidadCarga
{
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public int Productos { get; set; }
}

/// <summary>Lo que se puede elegir para el reporte de carga: solo lo que ese camión lleva.</summary>
public class OpcionesCargaResponse
{
    public List<OpcionMercadoCarga> Mercados { get; set; } = [];
    public List<OpcionUnidadCarga> Unidades { get; set; } = [];
}

public class ResumenDespachosResponse
{
    public int Total { get; set; }
    public int Armados { get; set; }
    public int PedidosEnRuta { get; set; }
}
