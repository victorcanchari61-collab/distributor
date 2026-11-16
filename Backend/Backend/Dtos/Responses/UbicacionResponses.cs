using Backend.Models;

namespace Backend.Dtos.Responses;

/// <summary>Un lugar dentro de un almacén, con lo que hace falta para dibujar el árbol.</summary>
public class UbicacionResponse
{
    public int Id { get; set; }
    public int AlmacenId { get; set; }
    public int? PadreId { get; set; }

    public string Tipo { get; set; } = string.Empty;
    public string TipoEtiqueta { get; set; } = string.Empty;
    public string Codigo { get; set; } = string.Empty;
    public string? Nombre { get; set; }

    /// <summary>Los códigos desde la raíz, unidos con guion: "P1-A-03". Es como se nombra el lugar.</summary>
    public string Ruta { get; set; } = string.Empty;

    /// <summary>Cuántos escalones tiene arriba: 0 en la raíz del almacén.</summary>
    public int Nivel { get; set; }

    public bool Activo { get; set; }

    /// <summary>Cuántos lugares tiene directamente adentro.</summary>
    public int Hijos { get; set; }

    /// <summary>Cuántos productos están puestos aquí (no cuenta los de los lugares de adentro).</summary>
    public int Productos { get; set; }

    /// <summary>Dónde está dibujado en el plano de su piso, en celdas. Nulo: todavía no se dibujó.</summary>
    public int? PlanoX { get; set; }
    public int? PlanoY { get; set; }
    public int? PlanoAncho { get; set; }
    public int? PlanoAlto { get; set; }

    /// <summary>Las partes extra (un cuarto en forma de L). Vacío: el lugar es solo su rectángulo principal.</summary>
    public List<RectPlano> PlanoPartes { get; set; } = [];

    /// <summary>Doble altura: el piso hasta donde está abierto. Nulo: solo ocupa su piso.</summary>
    public int? PlanoHastaPisoId { get; set; }

    /// <summary>Los pisos que ocupa en el plano, de abajo hacia arriba: el suyo y, con doble altura, los de encima.</summary>
    public List<int> PlanoPisos { get; set; } = [];
}

/// <summary>Un pasillo o una escalera del plano.</summary>
public class ElementoPlanoResponse
{
    public int Id { get; set; }
    public int? PisoId { get; set; }

    /// <summary>Solo escaleras: el piso al que llega.</summary>
    public int? HastaPisoId { get; set; }

    /// <summary>
    /// Los pisos donde se dibuja, de abajo hacia arriba: el suyo y, una escalera, todos los que cruza hasta el de
    /// llegada. Vacío en un almacén sin pisos.
    /// </summary>
    public List<int> Pisos { get; set; } = [];

    public string Tipo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public int X { get; set; }
    public int Y { get; set; }
    public int Ancho { get; set; }
    public int Alto { get; set; }
}

/// <summary>Lo que hace falta para dibujar los planos de un almacén, además de sus lugares.</summary>
public class PlanoResponse
{
    public int AlmacenId { get; set; }
    public int Columnas { get; set; }
    public int Filas { get; set; }
    public List<ElementoPlanoResponse> Elementos { get; set; } = [];
}

/// <summary>Un producto puesto en un lugar.</summary>
public class UbicacionProductoResponse
{
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string? Categoria { get; set; }
    public string UnidadBase { get; set; } = string.Empty;
}

/// <summary>Un lugar donde está puesto un producto.</summary>
public class LugarDeProductoResponse
{
    public int UbicacionId { get; set; }

    /// <summary>"P1-A-E03".</summary>
    public string Ruta { get; set; } = string.Empty;

    /// <summary>"Abarrotes", si el lugar tiene nombre.</summary>
    public string? Nombre { get; set; }
}

/// <summary>Un producto del almacén con el lugar o los lugares donde está puesto.</summary>
public class ProductoUbicadoResponse
{
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public string? Categoria { get; set; }
    public string? Marca { get; set; }
    public string UnidadBase { get; set; } = string.Empty;

    /// <summary>Lo que hay en el almacén, en unidad base.</summary>
    public decimal Stock { get; set; }

    /// <summary>Vacío: tiene stock (o ya se le puso un lugar) pero nadie sabe dónde está.</summary>
    public List<LugarDeProductoResponse> Lugares { get; set; } = [];
}

public class ProductosUbicadosResponse
{
    public int AlmacenId { get; set; }

    /// <summary>Cuántos lugares tiene definidos el almacén: sin ninguno no hay dónde poner nada.</summary>
    public int Lugares { get; set; }

    public int SinLugar { get; set; }
    public List<ProductoUbicadoResponse> Items { get; set; } = [];
}
