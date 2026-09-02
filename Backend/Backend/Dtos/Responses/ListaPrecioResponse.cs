namespace Backend.Dtos.Responses;

public class ListaPrecioResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool EsPredeterminada { get; set; }
    public bool Activo { get; set; }

    /// <summary>Cuantos precios tiene cargados.</summary>
    public int Precios { get; set; }
}

public class PrecioResponse
{
    public int Id { get; set; }
    public int ListaPrecioId { get; set; }
    public string ListaPrecio { get; set; } = string.Empty;

    public int PresentacionId { get; set; }
    public string Presentacion { get; set; } = string.Empty;

    public int ProductoId { get; set; }
    public string Producto { get; set; } = string.Empty;

    public decimal Precio { get; set; }
    public decimal CantidadMinima { get; set; }

    /// <summary>
    /// Precio equivalente en unidad base, calculado como Precio / Factor. Es
    /// lo que deja comparar el saco contra el kilo suelto.
    /// </summary>
    public decimal PrecioUnidadBase { get; set; }

    /// <summary>Codigo de la unidad base, para leer el precio anterior.</summary>
    public string UnidadBase { get; set; } = string.Empty;

    public bool Activo { get; set; }
    public DateTime FechaActualizacion { get; set; }
}
