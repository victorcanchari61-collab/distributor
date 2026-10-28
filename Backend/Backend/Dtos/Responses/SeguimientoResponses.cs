namespace Backend.Dtos.Responses;

// ------------------------------------------------------------------ Catálogo y buscador

public class TipoContactoResponse
{
    public string Clave { get; set; } = string.Empty;
    public string Etiqueta { get; set; } = string.Empty;
}

public class ResultadoGestionResponse
{
    public string Clave { get; set; } = string.Empty;
    public string Etiqueta { get; set; } = string.Empty;

    /// <summary>positivo, espera, objecion, neutro o perdido: es el color.</summary>
    public string Tono { get; set; } = string.Empty;

    /// <summary>La guía de cuándo elegir este resultado.</summary>
    public string Cuando { get; set; } = string.Empty;
}

public class CatalogoSeguimientoResponse
{
    public List<TipoContactoResponse> Tipos { get; set; } = [];
    public List<ResultadoGestionResponse> Resultados { get; set; } = [];
}

/// <summary>Un cliente en la lista del buscador de Gestión y seguimiento.</summary>
public class ClienteBuscadoResponse
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string Documento { get; set; } = string.Empty;
    public string? Mercado { get; set; }
    public bool Activo { get; set; }
}

// ------------------------------------------------------------------ Ficha

public class EstadoClienteResponse
{
    /// <summary>CRITICO, RIESGO, SEGUIMIENTO, NORMAL o SIN_BASE.</summary>
    public string Clave { get; set; } = string.Empty;

    public string Etiqueta { get; set; } = string.Empty;
}

public class DatosClienteResponse
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;

    /// <summary>Empresa si tiene RUC; Persona si no.</summary>
    public string Tipo { get; set; } = string.Empty;

    public string TipoDoc { get; set; } = string.Empty;
    public string Documento { get; set; } = string.Empty;
    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public string? Direccion { get; set; }
    public string? Ciudad { get; set; }
    public string? Mercado { get; set; }
    public string? Ruta { get; set; }
    public string? Vendedor { get; set; }
    public string? ListaPrecio { get; set; }
    public string? DiaVisita { get; set; }

    /// <summary>La categoría que rige hoy (Socio, Mayorista...), si el cliente entró en un cálculo.</summary>
    public string? CategoriaCodigo { get; set; }

    public string? Categoria { get; set; }
    public string? CategoriaColor { get; set; }

    public bool Activo { get; set; }
    public DateTime FechaAlta { get; set; }
    public EstadoClienteResponse Estado { get; set; } = new();
}

public class UltimaCompraResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }
    public string Documento { get; set; } = string.Empty;
    public decimal Monto { get; set; }
}

public class KpisClienteResponse
{
    /// <summary>Nulo si nunca compró.</summary>
    public int? DiasSinComprar { get; set; }

    public UltimaCompraResponse? UltimaCompra { get; set; }

    /// <summary>Lo que debe hoy por sus ventas a crédito.</summary>
    public decimal SaldoPorCobrar { get; set; }
}

/// <summary>Del 1 de enero a hoy contra el mismo tramo del año anterior (o el rango que se pidió).</summary>
public class PeriodoClienteResponse
{
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }

    /// <summary>"1 ene - 27 oct 2026".</summary>
    public string Etiqueta { get; set; } = string.Empty;

    /// <summary>"1 ene - 27 oct 2025".</summary>
    public string EtiquetaAnterior { get; set; } = string.Empty;

    public decimal Ventas { get; set; }
    public int Compras { get; set; }
    public decimal TicketPromedio { get; set; }
    public decimal VentasAnterior { get; set; }

    /// <summary>Positiva si vendió más que el año anterior, negativa si cayó.</summary>
    public decimal Variacion { get; set; }

    /// <summary>Positiva si cayó, como en el reporte. Nula si el año anterior no compró.</summary>
    public decimal? CaidaPct { get; set; }
}

public class ProductoPrincipalResponse
{
    public string Producto { get; set; } = string.Empty;
    public string? Codigo { get; set; }
    public decimal Monto { get; set; }
    public decimal Porcentaje { get; set; }
}

/// <summary>Lo que compró un cliente en un mes.</summary>
public class MesClienteResponse
{
    /// <summary>El primer día del mes.</summary>
    public DateTime Mes { get; set; }

    public decimal Importe { get; set; }
}

public class GestionResponse
{
    public int Id { get; set; }
    public int ClienteId { get; set; }

    /// <summary>Cuándo se hizo el contacto (instante, UTC).</summary>
    public DateTime Fecha { get; set; }

    public string TipoContacto { get; set; } = string.Empty;
    public string TipoEtiqueta { get; set; } = string.Empty;
    public string Resultado { get; set; } = string.Empty;
    public string ResultadoEtiqueta { get; set; } = string.Empty;
    public string Tono { get; set; } = string.Empty;
    public string? Comentario { get; set; }
    public string? RegistradoPor { get; set; }

    /// <summary>El día y la hora del siguiente contacto (instante, UTC).</summary>
    public DateTime? ProximoSeguimiento { get; set; }

    public string? ProximoTipoContacto { get; set; }
    public string? ProximoTipoEtiqueta { get; set; }
    public string? ProximaAccion { get; set; }

    /// <summary>PROGRAMADO o CUMPLIDO. Nulo si no se dejó siguiente contacto.</summary>
    public string? SeguimientoEstado { get; set; }

    /// <summary>El siguiente contacto sigue programado y su hora ya pasó.</summary>
    public bool Vencida { get; set; }
}

public class FichaClienteResponse
{
    public DatosClienteResponse Cliente { get; set; } = new();
    public KpisClienteResponse Kpis { get; set; } = new();
    public PeriodoClienteResponse Periodo { get; set; } = new();
    public GestionResponse? UltimaGestion { get; set; }
    public GestionResponse? ProximaGestion { get; set; }
    public List<ProductoPrincipalResponse> ProductosPrincipales { get; set; } = [];

    /// <summary>
    /// Lo que compró en cada uno de los últimos 24 meses, del más antiguo al más reciente: los 12 primeros son el año
    /// anterior y los 12 últimos, el año en curso.
    /// </summary>
    public List<MesClienteResponse> Meses { get; set; } = [];
}

public class GestionesClienteResponse
{
    /// <summary>De la más reciente a la más antigua.</summary>
    public List<GestionResponse> Items { get; set; } = [];

    /// <summary>El contacto que sigue programado, si lo hay.</summary>
    public GestionResponse? ProximaGestion { get; set; }

    /// <summary>Cuántas gestiones van desde el 1 de enero.</summary>
    public int TotalAnio { get; set; }

    public DateTime DesdeAnio { get; set; }
}

// ------------------------------------------------------------------ Compras y documentos

public class CompraClienteResponse
{
    public int NotaVentaId { get; set; }
    public string Numero { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string FormaPago { get; set; } = string.Empty;
    public string? Vendedor { get; set; }
    public decimal Total { get; set; }
    public decimal Pagado { get; set; }
    public decimal Saldo { get; set; }
}

/// <summary>Un producto del cliente en los dos periodos: qué dejó de comprar, qué compra más y qué es nuevo.</summary>
public class SituacionProductoResponse
{
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public decimal VentaAnterior { get; set; }
    public decimal VentaActual { get; set; }
    public decimal Variacion { get; set; }

    /// <summary>DEJO, NUEVO, IGUAL, MAS o MENOS.</summary>
    public string Situacion { get; set; } = string.Empty;
}

public class ComprasClienteResponse
{
    public PeriodoClienteResponse Periodo { get; set; } = new();
    public List<CompraClienteResponse> Ventas { get; set; } = [];
    public List<SituacionProductoResponse> Productos { get; set; } = [];
}

public class PedidoClienteResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string CondicionPago { get; set; } = string.Empty;
}

public class DevolucionClienteResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;
    public string NotaVenta { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string? Motivo { get; set; }
}

public class DocumentosClienteResponse
{
    public List<PedidoClienteResponse> Pedidos { get; set; } = [];
    public List<DevolucionClienteResponse> Devoluciones { get; set; } = [];
}

// ------------------------------------------------------------------ Recordatorios

/// <summary>Cuántos contactos programados tiene una persona: lo que avisa la campanita.</summary>
public class ResumenSeguimientoResponse
{
    public int Vencidos { get; set; }
    public int Hoy { get; set; }

    /// <summary>La hora más antigua entre los vencidos, si hay alguno.</summary>
    public DateTime? VencidoDesde { get; set; }
}
