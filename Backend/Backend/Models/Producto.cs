namespace Backend.Models;

/// <summary>
/// Producto del catalogo.
///
/// El stock de un producto se lleva SIEMPRE en su unidad base: kilos para el
/// azucar, unidades (botellas) para el aceite. Comprar un saco de 50 suma 50
/// kilos y vender 3 kilos resta 3, sin importar en que presentacion se hizo la
/// operacion. Las equivalencias viven en <see cref="ProductoPresentacion"/>.
///
/// Cada medida de un envasado es un producto distinto: "Aceite Primor 1 L" y
/// "Aceite Primor 900 ml" son dos productos, porque tienen stock y precio
/// propios. Lo que comparten es marca y categoria.
/// </summary>
public class Producto
{
    public int Id { get; set; }

    /// <summary>Codigo interno con el que se busca el producto. No se repite.</summary>
    public string Codigo { get; set; } = string.Empty;

    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }

    public int? CategoriaId { get; set; }
    public Categoria? Categoria { get; set; }

    public int? MarcaId { get; set; }
    public Marca? Marca { get; set; }

    /// <summary>Unidad en la que se guarda el stock: KG, UND, LT.</summary>
    public int UnidadBaseId { get; set; }
    public UnidadMedida? UnidadBase { get; set; }

    /// <summary>
    /// Cuanto contiene el envase, para productos envasados: 900 junto a la
    /// unidad ML. Es informativo — sirve para comparar precio por litro — y no
    /// interviene en el stock.
    /// </summary>
    public decimal? Contenido { get; set; }

    public int? ContenidoUnidadId { get; set; }
    public UnidadMedida? ContenidoUnidad { get; set; }

    /// <summary>Servicios y similares no descuentan stock.</summary>
    public bool ControlaStock { get; set; } = true;

    /// <summary>Aviso de reposicion, en unidad base.</summary>
    public decimal StockMinimo { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<ProductoPresentacion> Presentaciones { get; set; } = [];
}
