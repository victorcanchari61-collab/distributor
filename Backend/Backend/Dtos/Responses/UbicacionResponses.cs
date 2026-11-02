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
