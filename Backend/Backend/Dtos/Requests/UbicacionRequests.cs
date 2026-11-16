namespace Backend.Dtos.Requests;

/// <summary>Un lugar nuevo dentro de un almacén: un piso o un cuarto</summary>
public class CrearUbicacionRequest
{
    /// <summary>El piso que lo va a contener (solo para un cuarto). Sin valor, queda directo en el almacén.</summary>
    public int? PadreId { get; set; }

    /// <summary>PISO o CUARTO.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>
    /// El código corto de este punto ("P1", "01"). Vacío: se pone solo, el siguiente número del nivel (P3 si ya hay
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

/// <summary>Dónde dibujar un lugar en el plano de su piso, en celdas. Todo nulo: se saca del plano (el lugar queda).</summary>
public class PosicionPlanoRequest
{
    public int? X { get; set; }
    public int? Y { get; set; }
    public int? Ancho { get; set; }
    public int? Alto { get; set; }

    /// <summary>
    /// Las partes extra del lugar (forma de L), todas: reemplazan a las que tenía. Nulo o vacío: solo el rectángulo
    /// principal. Cada parte tiene que tocar al resto del lugar.
    /// </summary>
    public List<RectPlanoRequest>? Partes { get; set; }
}

/// <summary>Un rectángulo de la cuadrícula, en celdas.</summary>
public class RectPlanoRequest
{
    public int X { get; set; }
    public int Y { get; set; }
    public int Ancho { get; set; }
    public int Alto { get; set; }
}

/// <summary>Un pasillo o una escalera del plano: dónde, de qué tamaño y cómo se llama.</summary>
public class ElementoPlanoRequest
{
    /// <summary>El piso en cuyo plano va. Nulo: el almacén no usa pisos. Al cambiarlo de lugar no se usa.</summary>
    public int? PisoId { get; set; }

    /// <summary>PASILLO o ESCALERA. Al cambiarlo de lugar no se usa: no cambia de tipo.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>
    /// Solo escaleras: el piso al que llega (obligatorio al crearla; al cambiarla, sin dato se queda el que tenía).
    /// </summary>
    public int? HastaPisoId { get; set; }

    public string Nombre { get; set; } = string.Empty;
    public int X { get; set; }
    public int Y { get; set; }
    public int Ancho { get; set; }
    public int Alto { get; set; }
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
