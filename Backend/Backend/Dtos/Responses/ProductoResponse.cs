namespace Backend.Dtos.Responses;

public class ProductoResponse
{
    public int Id { get; set; }

    /// <summary>Si ya tiene stock, kardex o costos: cambiar su unidad base no los convierte.</summary>
    public bool TieneMovimientos { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }

    public int? CategoriaId { get; set; }
    public string? Categoria { get; set; }

    public int? MarcaId { get; set; }
    public string? Marca { get; set; }

    public int UnidadBaseId { get; set; }

    /// <summary>Codigo de la unidad base: KG, UND, LT.</summary>
    public string UnidadBase { get; set; } = string.Empty;

    /// <summary>Contenido del envase, ya legible: "900 ML".</summary>
    public decimal? Contenido { get; set; }
    public int? ContenidoUnidadId { get; set; }
    public string? ContenidoUnidad { get; set; }

    /// <summary>Costo habitual por unidad base.</summary>
    public decimal? CostoReferencia { get; set; }

    public bool ControlaStock { get; set; }
    public decimal StockMinimo { get; set; }
    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }

    public List<PresentacionResponse> Presentaciones { get; set; } = [];
}

public class PresentacionResponse
{
    public int Id { get; set; }
    public int ProductoId { get; set; }
    public int UnidadId { get; set; }
    public string Unidad { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;

    /// <summary>Cuantas unidades base equivale.</summary>
    public decimal Factor { get; set; }

    /// <summary>True en la presentacion de factor 1, que no se puede borrar.</summary>
    public bool EsBase { get; set; }

    public bool EsCompra { get; set; }
    public bool EsVenta { get; set; }
    public bool PredeterminadaVenta { get; set; }
    public bool PredeterminadaCompra { get; set; }

    /// <summary>Los documentos de inventario impresos salen por esta presentación y no por unidad base.</summary>
    public bool PrecioPorPresentacion { get; set; }

    public string? CodigoBarras { get; set; }
    public bool Activo { get; set; }
}
