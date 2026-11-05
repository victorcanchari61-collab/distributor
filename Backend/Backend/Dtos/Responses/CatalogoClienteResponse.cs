namespace Backend.Dtos.Responses;

/// <summary>
/// El catálogo que se le muestra al cliente: solo lo que se puede ver y consultar, nunca costos ni stock.
/// </summary>
public class CatalogoClienteResponse
{
    /// <summary>Las listas de precios activas, para elegir con cuál se muestra el catálogo.</summary>
    public List<CatalogoListaResponse> Listas { get; set; } = [];

    /// <summary>La lista con la que vienen los precios de este catálogo.</summary>
    public int? ListaId { get; set; }

    public List<string> Categorias { get; set; } = [];
    public List<string> Marcas { get; set; } = [];
    public List<CatalogoProductoResponse> Productos { get; set; } = [];
}

public class CatalogoListaResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public bool EsPredeterminada { get; set; }
}

public class CatalogoProductoResponse
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public string? Categoria { get; set; }
    public string? Marca { get; set; }

    /// <summary>Ruta de la foto ("/uploads/productos/..."), o nada si no tiene.</summary>
    public string? Foto { get; set; }

    /// <summary>Unidad base legible: "Kilogramo".</summary>
    public string UnidadBase { get; set; } = string.Empty;

    /// <summary>Contenido del envase ya legible: "900 ML". Vacío en lo que no es envasado.</summary>
    public string? Contenido { get; set; }

    /// <summary>El precio más bajo entre sus presentaciones, para "desde S/ ...". Siempre mayor que cero.</summary>
    public decimal PrecioDesde { get; set; }

    /// <summary>Las formas en que se vende, de la más chica a la más grande.</summary>
    public List<CatalogoPresentacionResponse> Presentaciones { get; set; } = [];
}

public class CatalogoPresentacionResponse
{
    /// <summary>Como se lee: "Saco 50 kg", "Caja x 12".</summary>
    public string Nombre { get; set; } = string.Empty;

    public string Unidad { get; set; } = string.Empty;

    /// <summary>Cuántas unidades base trae.</summary>
    public decimal Factor { get; set; }

    /// <summary>Precio de UNA presentación completa.</summary>
    public decimal Precio { get; set; }

    /// <summary>Precio por unidad base (el kilo, la botella): deja comparar el saco con el suelto.</summary>
    public decimal PrecioUnidadBase { get; set; }

    /// <summary>Precios por volumen: "desde 10, a S/ ...". Vacío si no hay escalones.</summary>
    public List<CatalogoEscalonResponse> Escalones { get; set; } = [];
}

public class CatalogoEscalonResponse
{
    public decimal CantidadMinima { get; set; }
    public decimal Precio { get; set; }
}

// ---------------------------------------------------------------------------------------------------------------------
// Versión PÚBLICA: la que ve cualquiera con el enlace, sin sesión. Solo lo que un cliente debe ver: ni ids internos, ni
// códigos, ni listas de precios, ni nada que no sea nombre, foto, precio y presentaciones.
// ---------------------------------------------------------------------------------------------------------------------

public class CatalogoPublicoResponse
{
    /// <summary>Nombre comercial de la empresa, para el encabezado.</summary>
    public string Empresa { get; set; } = string.Empty;

    /// <summary>Teléfono de contacto de la empresa, si lo tiene cargado.</summary>
    public string? Telefono { get; set; }

    public List<string> Categorias { get; set; } = [];
    public List<string> Marcas { get; set; } = [];
    public List<CatalogoPublicoProductoResponse> Productos { get; set; } = [];
}

public class CatalogoPublicoProductoResponse
{
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public string? Categoria { get; set; }
    public string? Marca { get; set; }
    public string? Foto { get; set; }
    public string UnidadBase { get; set; } = string.Empty;
    public string? Contenido { get; set; }
    public decimal PrecioDesde { get; set; }
    public List<CatalogoPresentacionResponse> Presentaciones { get; set; } = [];
}
