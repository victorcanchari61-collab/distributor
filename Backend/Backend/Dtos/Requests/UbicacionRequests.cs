namespace Backend.Dtos.Requests;

/// <summary>Un lugar nuevo dentro de un almacén: un piso o un cuarto</summary>
public class CrearUbicacionRequest
{
    /// <summary>El piso que lo va a contener (solo para un cuarto). Sin valor, queda directo en el almacén.</summary>
    public int? PadreId { get; set; }

    /// <summary>PISO o CUARTO.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>El código corto de este punto: "P1", "C1". No se repite entre hermanos.</summary>
    public string Codigo { get; set; } = string.Empty;

    public string? Nombre { get; set; }
}

/// <summary>Cambiar un lugar. No se mueve de padre: para eso se crea de nuevo donde corresponde.</summary>
public class ActualizarUbicacionRequest
{
    public string Tipo { get; set; } = string.Empty;
    public string Codigo { get; set; } = string.Empty;
    public string? Nombre { get; set; }
    public bool Activo { get; set; } = true;
}

/// <summary>
/// Crear varios lugares seguidos de una vez: los cuartos C1 a C8 de un piso, los pisos P1 a P3.
/// El código de cada uno es el prefijo y el número con ceros a la izquierda.
/// </summary>
public class GenerarUbicacionesRequest
{
    public int? PadreId { get; set; }
    public string Tipo { get; set; } = string.Empty;

    /// <summary>La parte fija del código ("E"). Puede ir vacío para códigos solo numéricos.</summary>
    public string? Prefijo { get; set; }

    public int Desde { get; set; } = 1;
    public int Hasta { get; set; }

    /// <summary>Cuántos dígitos lleva el número: con 2, "01", "02"... Sin valor, 2.</summary>
    public int Digitos { get; set; } = 2;
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
