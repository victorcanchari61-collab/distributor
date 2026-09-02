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
