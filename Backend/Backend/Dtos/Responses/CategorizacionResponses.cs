namespace Backend.Dtos.Responses;

public class CategoriaClienteResponse
{
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
    public decimal Desde { get; set; }

    /// <summary>El tope del tramo: lo que falta para llegar a la categoría de arriba. Nulo en la más alta.</summary>
    public decimal? Hasta { get; set; }

    /// <summary>Cuántos clientes tiene hoy, según el último cálculo.</summary>
    public int Clientes { get; set; }
}

/// <summary>Las fechas de un ciclo: qué se evalúa y desde cuándo rige.</summary>
public class CategorizacionVentanaResponse
{
    public DateTime EvaluadoDesde { get; set; }
    public DateTime EvaluadoHasta { get; set; }
    public DateTime VigenteDesde { get; set; }

    /// <summary>El último día en que rige. El resultado cambia al día siguiente.</summary>
    public DateTime VigenteHasta { get; set; }
}

/// <summary>El último cálculo que está rigiendo.</summary>
public class CalculoVigenteResponse
{
    public int Id { get; set; }
    public string Ciclo { get; set; } = string.Empty;
    public CategorizacionVentanaResponse Ventana { get; set; } = new();

    /// <summary>Cuándo se calculó (instante, UTC).</summary>
    public DateTime CalculadoEn { get; set; }

    public bool Automatico { get; set; }
    public string? Usuario { get; set; }
    public int Clientes { get; set; }

    /// <summary>Ya pasó el último día en que regía y nadie lo recalculó.</summary>
    public bool Vencido { get; set; }
}

public class CategorizacionResponse
{
    public string Ciclo { get; set; } = string.Empty;
    public List<CategoriaClienteResponse> Categorias { get; set; } = [];

    /// <summary>Lo que se evaluaría si se calculara hoy con el ciclo configurado.</summary>
    public CategorizacionVentanaResponse Ventana { get; set; } = new();

    /// <summary>Nulo mientras nadie haya calculado.</summary>
    public CalculoVigenteResponse? Vigente { get; set; }

    /// <summary>El ciclo configurado no es el del cálculo vigente: hay que calcular de nuevo para que rija.</summary>
    public bool CicloDistinto { get; set; }
}

/// <summary>Un cliente con su categoría y cómo se movió desde el cálculo anterior.</summary>
public class ClienteCategoriaResponse
{
    public int ClienteId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Documento { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Ruta { get; set; }
    public string? Mercado { get; set; }

    /// <summary>La letra de su categoría (A a F).</summary>
    public string Categoria { get; set; } = string.Empty;

    /// <summary>Lo que compró en el ciclo evaluado.</summary>
    public decimal Monto { get; set; }

    /// <summary>La letra que tenía en el cálculo anterior. Nulo si no estaba.</summary>
    public string? CategoriaAnterior { get; set; }

    /// <summary>SUBE, BAJA, IGUAL o NUEVO (no estaba en el cálculo anterior).</summary>
    public string Movimiento { get; set; } = string.Empty;
}
