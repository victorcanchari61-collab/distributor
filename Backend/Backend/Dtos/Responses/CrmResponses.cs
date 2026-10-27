namespace Backend.Dtos.Responses;

/// <summary>Un rango de días del negocio, ambos incluidos.</summary>
public class CrmRango
{
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }
}

/// <summary>
/// Qué se compara con qué: el periodo en curso contra el anterior, de la misma longitud.
/// Viaja en la respuesta para que la pantalla diga exactamente qué fechas está comparando.
/// </summary>
public class CrmVentanas
{
    /// <summary>semana, mes o anio.</summary>
    public string Periodo { get; set; } = string.Empty;
    public CrmRango Actual { get; set; } = new();
    public CrmRango Anterior { get; set; } = new();
}

/// <summary>Un cliente de la cartera, con lo que compró ahora y antes.</summary>
public class CrmClienteResponse
{
    public int ClienteId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Documento { get; set; } = string.Empty;
    public string TipoDoc { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Telefono { get; set; }
    public string? Direccion { get; set; }
    public string? Distrito { get; set; }

    /// <summary>El flag del maestro de clientes. Distinto de <see cref="Inactivo"/>, que mira las compras.</summary>
    public bool Activo { get; set; }

    public int? RutaId { get; set; }
    public string? Ruta { get; set; }
    public int? MercadoId { get; set; }
    public string? Mercado { get; set; }
    public int? VendedorId { get; set; }
    public string? Vendedor { get; set; }

    public decimal Actual { get; set; }
    public decimal Anterior { get; set; }

    /// <summary>Actual menos anterior: negativo es plata que se dejó de vender.</summary>
    public decimal Diferencia { get; set; }

    /// <summary>
    /// Cambio en porcentaje contra el periodo anterior (-83.3 es una caída de 83.3 %). Nulo cuando no
    /// había compras antes y por eso no hay contra qué comparar.
    /// </summary>
    public decimal? Variacion { get; set; }

    /// <summary>CRITICO, ALTO, MEDIO, ESTABLE, NUEVO o INACTIVO.</summary>
    public string Nivel { get; set; } = string.Empty;

    public DateTime? UltimaCompra { get; set; }
    public int? DiasSinComprar { get; set; }

    /// <summary>Lleva más de los días de gracia sin comprar nada.</summary>
    public bool Inactivo { get; set; }

    /// <summary>Lo que debe hoy, de sus ventas a crédito.</summary>
    public decimal SaldoPorCobrar { get; set; }

    /// <summary>La acción pendiente más próxima que se anotó en su seguimiento, si hay alguna.</summary>
    public string? ProximaAccion { get; set; }

    /// <summary>El día de esa acción.</summary>
    public DateTime? ProximaFecha { get; set; }

    /// <summary>Esa acción ya debió hacerse (su día es anterior a hoy).</summary>
    public bool AccionVencida { get; set; }

    /// <summary>Cuándo fue la última gestión con el cliente (instante).</summary>
    public DateTime? UltimaGestion { get; set; }

    /// <summary>La letra de su categoría (A a F) según el último cálculo. Nulo si nunca se calculó.</summary>
    public string? CategoriaCodigo { get; set; }

    /// <summary>El nombre de esa categoría (Socio, Distribuidor...).</summary>
    public string? Categoria { get; set; }

    /// <summary>El color con el que se pinta (sky, emerald, amber...).</summary>
    public string? CategoriaColor { get; set; }
}

public class CrmResumenResponse
{
    public int Clientes { get; set; }
    public int Criticos { get; set; }
    public int Altos { get; set; }
    public int Medios { get; set; }
    public int Estables { get; set; }
    public int Nuevos { get; set; }
    public int Inactivos { get; set; }

    /// <summary>Clientes con una acción de seguimiento cuyo día ya pasó.</summary>
    public int AccionesVencidas { get; set; }

    public decimal Actual { get; set; }
    public decimal Anterior { get; set; }
    public decimal Diferencia { get; set; }
    public decimal? Variacion { get; set; }

    /// <summary>
    /// Lo que se dejó de vender solo entre los clientes que bajaron: la caída bruta, sin que las
    /// subidas de otros la tapen.
    /// </summary>
    public decimal VentaPerdida { get; set; }
}

public class CrmCarteraResponse
{
    public CrmVentanas Ventanas { get; set; } = new();
    public CrmResumenResponse Resumen { get; set; } = new();

    /// <summary>Los que más plata dejaron de comprar, primero.</summary>
    public List<CrmClienteResponse> Items { get; set; } = [];

    /// <summary>Quien pregunta ve solo parte de la cartera (según su alcance).</summary>
    public bool SoloPropios { get; set; }

    /// <summary>Días sin comprar a partir de los cuales un cliente se considera inactivo.</summary>
    public int DiasInactivo { get; set; }
}

// ------------------------------------------------------------------ Ficha

public class CrmComparativoResponse
{
    public string Periodo { get; set; } = string.Empty;
    public CrmRango Actual { get; set; } = new();
    public CrmRango Anterior { get; set; } = new();
    public decimal ImporteActual { get; set; }
    public decimal ImporteAnterior { get; set; }
    public decimal Diferencia { get; set; }
    public decimal? Variacion { get; set; }
    public string Nivel { get; set; } = string.Empty;
}

public class CrmCompraResponse
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

/// <summary>Un producto que el cliente compraba y compra menos —o ya no compra—.</summary>
public class CrmProductoPerdidoResponse
{
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public decimal Actual { get; set; }
    public decimal Anterior { get; set; }
    public decimal Diferencia { get; set; }

    /// <summary>En el periodo en curso no compró nada de este producto.</summary>
    public bool DejoDeComprar { get; set; }
}

public class CrmPedidoResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string CondicionPago { get; set; } = string.Empty;
}

public class CrmDevolucionResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;
    public string NotaVenta { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string? Motivo { get; set; }
}

public class CrmFichaResponse
{
    public CrmClienteResponse Cliente { get; set; } = new();

    /// <summary>Con qué periodo se calcularon el nivel, la caída y los productos perdidos.</summary>
    public string Periodo { get; set; } = string.Empty;

    public string? Email { get; set; }
    public string? DiaVisita { get; set; }
    public string? ListaPrecio { get; set; }
    public DateTime FechaAlta { get; set; }

    /// <summary>La caída en las tres escalas a la vez: semana, mes y año.</summary>
    public List<CrmComparativoResponse> Comparativos { get; set; } = [];

    public List<CrmCompraResponse> Compras { get; set; } = [];
    public List<CrmProductoPerdidoResponse> ProductosPerdidos { get; set; } = [];
    public List<CrmPedidoResponse> Pedidos { get; set; } = [];
    public List<CrmDevolucionResponse> Devoluciones { get; set; } = [];
}

/// <summary>Una gestión del historial de un cliente.</summary>
public class GestionResponse
{
    public int Id { get; set; }
    public int ClienteId { get; set; }

    /// <summary>Cuándo se hizo el contacto (instante, UTC).</summary>
    public DateTime Fecha { get; set; }

    public string Tipo { get; set; } = string.Empty;
    public string Resultado { get; set; } = string.Empty;
    public string Nota { get; set; } = string.Empty;
    public string? ProximaAccion { get; set; }

    /// <summary>El día de la próxima acción.</summary>
    public DateTime? ProximaFecha { get; set; }

    public bool Cumplida { get; set; }
    public DateTime? CumplidaEn { get; set; }

    /// <summary>La acción sigue abierta y su día ya pasó.</summary>
    public bool Vencida { get; set; }

    public int? UsuarioId { get; set; }
    public string? Usuario { get; set; }
}
