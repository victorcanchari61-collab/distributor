namespace Backend.Dtos.Responses;

/// <summary>Contadores del catálogo completo de productos, no de la página visible.</summary>
public class ResumenProductosResponse
{
    public int Activos { get; set; }
    public int Desactivados { get; set; }

    /// <summary>Cuántas presentaciones hay declaradas en total.</summary>
    public int Presentaciones { get; set; }

    /// <summary>Valores existentes por columna, para los filtros de tipo lista.</summary>
    public List<string> Categorias { get; set; } = [];
    public List<string> Marcas { get; set; } = [];
}
