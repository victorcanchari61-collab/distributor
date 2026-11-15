namespace Backend.Dtos.Requests;

/// <summary>Un lugar nuevo dentro de un almacén: un piso o un cuarto</summary>
public class CrearUbicacionRequest
{
    /// <summary>El piso que lo va a contener (solo para un cuarto). Sin valor, queda directo en el almacén.</summary>
    public int? PadreId { get; set; }

    /// <summary>PISO o CUARTO.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>
    /// El código corto de este punto ("P1", "C1"). Vacío: se pone solo, el siguiente número del nivel (P3 si ya hay
    /// P1 y P2). No se repite entre hermanos.
    /// </summary>
    public string? Codigo { get; set; }

    /// <summary>Cómo se le dice: "Azotea", "Cocina".</summary>
    public string Nombre { get; set; } = string.Empty;
}

/// <summary>
/// Cambiar un lugar. No se mueve de padre ni cambia de nivel (un piso no pasa a cuarto): eso rompería lo que tiene
/// adentro. Para eso se crea de nuevo donde corresponde.
/// </summary>
public class ActualizarUbicacionRequest
{
    public string Codigo { get; set; } = string.Empty;
    public string? Nombre { get; set; }
    public bool Activo { get; set; } = true;
}

/// <summary>Poner un producto en un lugar del almacén.</summary>
public class AsignarProductoUbicacionRequest
{
    public int ProductoId { get; set; }
}

/// <summary>Poner varios productos en un lugar de una vez.</summary>
public class AsignarProductosUbicacionRequest
{
    public int UbicacionId { get; set; }
    public List<int> ProductoIds { get; set; } = [];

    /// <summary>
    /// Mover en vez de sumar: antes de ponerlos aquí, se les quita el lugar que tuvieran en ESTE almacén. Sin esto, el
    /// producto queda puesto aquí además de donde ya estaba.
    /// </summary>
    public bool Reemplazar { get; set; }
}

/// <summary>Sacar varios productos de un lugar.</summary>
public class QuitarProductosUbicacionRequest
{
    public int UbicacionId { get; set; }
    public List<int> ProductoIds { get; set; } = [];
}
