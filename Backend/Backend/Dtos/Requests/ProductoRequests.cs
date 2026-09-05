namespace Backend.Dtos.Requests;

public abstract class ProductoRequestBase
{
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public int? CategoriaId { get; set; }
    public int? MarcaId { get; set; }

    /// <summary>Unidad en la que se lleva el stock. No cambia despues de crear.</summary>
    public int UnidadBaseId { get; set; }

    public decimal? Contenido { get; set; }
    public int? ContenidoUnidadId { get; set; }

    /// <summary>Costo habitual por unidad base. Referencia, no el del stock.</summary>
    public decimal? CostoReferencia { get; set; }

    public bool ControlaStock { get; set; } = true;
    public decimal StockMinimo { get; set; }
}

public class CreateProductoRequest : ProductoRequestBase
{
    /// <summary>
    /// Presentaciones ademas de la base. La de factor 1 se crea sola con la
    /// unidad base, para que ningun producto quede sin forma de venderse.
    /// </summary>
    public List<PresentacionRequest> Presentaciones { get; set; } = [];
}

public class UpdateProductoRequest : ProductoRequestBase
{
    public bool Activo { get; set; } = true;
}

/// <summary>
/// Una fila de un catálogo de un sistema viejo: trae la unidad por código
/// ("KG", "UND") en vez de por id, y hasta tres precios sueltos en vez de la
/// estructura de listas — el servicio se encarga de traducir ambas cosas.
/// </summary>
public class CreateProductoImportRequest
{
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string UnidadBaseCodigo { get; set; } = string.Empty;
    public decimal? CostoReferencia { get; set; }

    /// <summary>Factores de presentaciones adicionales a la base (factor 1).</summary>
    public List<decimal> Presentaciones { get; set; } = [];

    /// <summary>Precio en la lista predeterminada (contado).</summary>
    public decimal? PrecioContado { get; set; }

    /// <summary>Precio en la lista "Por saco" (se crea si no existe).</summary>
    public decimal? PrecioPorSaco { get; set; }

    /// <summary>Precio en la lista "Mayorista" (se crea si no existe).</summary>
    public decimal? PrecioMayorista { get; set; }
}

public class PresentacionRequest
{
    public int UnidadId { get; set; }
    public string Nombre { get; set; } = string.Empty;

    /// <summary>Cuantas unidades base equivale. Mayor que cero.</summary>
    public decimal Factor { get; set; }

    public bool EsCompra { get; set; } = true;
    public bool EsVenta { get; set; } = true;
    public bool PredeterminadaVenta { get; set; }
    public bool PredeterminadaCompra { get; set; }
    public string? CodigoBarras { get; set; }
    public bool Activo { get; set; } = true;
}
