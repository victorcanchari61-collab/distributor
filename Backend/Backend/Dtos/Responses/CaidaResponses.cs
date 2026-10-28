namespace Backend.Dtos.Responses;

/// <summary>Un rango de días del negocio, ambos incluidos.</summary>
public class RangoResponse
{
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }
}

/// <summary>Qué se mide y contra qué: el tramo pedido y el mismo tramo del año anterior.</summary>
public class PeriodoCaidaResponse
{
    public RangoResponse Actual { get; set; } = new();
    public RangoResponse Anterior { get; set; } = new();

    /// <summary>"1 ene - 27 oct 2026".</summary>
    public string Etiqueta { get; set; } = string.Empty;

    /// <summary>"1 ene - 27 oct 2025".</summary>
    public string EtiquetaAnterior { get; set; } = string.Empty;
}

/// <summary>Una tarjeta de un reporte: cuántos hay en un estado y cuánta venta está en juego.</summary>
public class EstadoResumenResponse
{
    public string Estado { get; set; } = string.Empty;
    public string Etiqueta { get; set; } = string.Empty;
    public int Clientes { get; set; }

    /// <summary>Lo que se dejó de vender (caída) o lo que compraban en el último año (inactivos).</summary>
    public decimal Monto { get; set; }
}

// ------------------------------------------------------------------ Clientes con caída

public class CaidaFilaResponse
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Cliente { get; set; } = string.Empty;
    public string Documento { get; set; } = string.Empty;
    public string? Telefono { get; set; }
    public string? Vendedor { get; set; }
    public int? VendedorId { get; set; }
    public string? Mercado { get; set; }
    public int? MercadoId { get; set; }
    public string? Ruta { get; set; }
    public int? RutaId { get; set; }
    public string? CategoriaCodigo { get; set; }
    public string? Categoria { get; set; }
    public string? CategoriaColor { get; set; }

    public DateTime? UltimaCompra { get; set; }
    public int? DiasSinCompra { get; set; }

    public decimal VentaAnterior { get; set; }
    public decimal VentaActual { get; set; }

    /// <summary>Actual menos anterior: negativa es plata que se dejó de vender.</summary>
    public decimal Variacion { get; set; }

    /// <summary>Positiva si cayó. Nula si el año anterior no compró.</summary>
    public decimal? CaidaPct { get; set; }

    /// <summary>Lo que dejó de comprar (cero si compra igual o más).</summary>
    public decimal MontoRiesgo { get; set; }

    public string Estado { get; set; } = string.Empty;
    public decimal SaldoPorCobrar { get; set; }

    // La última gestión del seguimiento, como estado resumido.
    public string? GestionResultado { get; set; }
    public string? GestionEtiqueta { get; set; }
    public string? GestionTono { get; set; }
    public DateTime? GestionFecha { get; set; }

    /// <summary>El contacto programado más próximo, si lo hay (instante, UTC).</summary>
    public DateTime? ProximoSeguimiento { get; set; }

    /// <summary>Qué se hará en ese contacto.</summary>
    public string? ProximaAccion { get; set; }

    public bool SeguimientoVencido { get; set; }
}

public class CaidaClientesResponse
{
    public PeriodoCaidaResponse Periodo { get; set; } = new();

    /// <summary>Una tarjeta por estado, de mayor a menor gravedad.</summary>
    public List<EstadoResumenResponse> Estados { get; set; } = [];

    public decimal VentaAnterior { get; set; }
    public decimal VentaActual { get; set; }

    /// <summary>Quien pregunta ve solo parte de los clientes (según su alcance).</summary>
    public bool SoloPropios { get; set; }

    public List<CaidaFilaResponse> Items { get; set; } = [];
}

/// <summary>Un producto del cliente: lo que dejó de comprar y lo que no.</summary>
public class QueDejoDeComprarResponse
{
    public int ClienteId { get; set; }
    public string Cliente { get; set; } = string.Empty;
    public PeriodoCaidaResponse Periodo { get; set; } = new();
    public List<SituacionProductoResponse> Productos { get; set; } = [];
}

// ------------------------------------------------------------------ Clientes inactivos

public class InactivoFilaResponse
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Cliente { get; set; } = string.Empty;
    public string Documento { get; set; } = string.Empty;
    public string? Telefono { get; set; }
    public string? Vendedor { get; set; }
    public string? Mercado { get; set; }
    public string? Ruta { get; set; }
    public string? CategoriaCodigo { get; set; }
    public string? Categoria { get; set; }
    public string? CategoriaColor { get; set; }

    public DateTime UltimaCompra { get; set; }
    public int DiasSinCompra { get; set; }

    /// <summary>Lo comprado en los últimos 12 meses antes de la última compra: lo que se pierde si no vuelve.</summary>
    public decimal Ventas12m { get; set; }

    public int Compras12m { get; set; }
    public decimal TicketPromedio { get; set; }

    /// <summary>CRITICO (61 días o más), RIESGO (31 a 60) o SEGUIMIENTO (16 a 30).</summary>
    public string Estado { get; set; } = string.Empty;
}

public class InactivosResponse
{
    /// <summary>El día desde el que se cuentan los días sin comprar.</summary>
    public DateTime Corte { get; set; }

    public List<EstadoResumenResponse> Estados { get; set; } = [];
    public bool SoloPropios { get; set; }
    public List<InactivoFilaResponse> Items { get; set; } = [];

    /// <summary>Clientes activos que nunca compraron, aparte de la lista.</summary>
    public int NuncaCompraron { get; set; }
}

// ------------------------------------------------------------------ Vendedores con caída

public class VendedorCaidaFilaResponse
{
    public int UsuarioId { get; set; }
    public string Vendedor { get; set; } = string.Empty;
    public decimal VentaAnterior { get; set; }
    public decimal VentaActual { get; set; }
    public decimal Variacion { get; set; }
    public decimal? CaidaPct { get; set; }
    public string Estado { get; set; } = string.Empty;

    /// <summary>Clientes a los que vendió en alguno de los dos tramos.</summary>
    public int Clientes { get; set; }

    /// <summary>De esos, cuántos compran menos que antes (En seguimiento o peor).</summary>
    public int ClientesEnCaida { get; set; }

    public int ClientesCriticos { get; set; }

    /// <summary>Lo que dejaron de comprar los clientes que bajaron.</summary>
    public decimal MontoRiesgo { get; set; }
}

public class VendedoresCaidaResponse
{
    public PeriodoCaidaResponse Periodo { get; set; } = new();
    public List<EstadoResumenResponse> Estados { get; set; } = [];
    public List<VendedorCaidaFilaResponse> Items { get; set; } = [];
}
