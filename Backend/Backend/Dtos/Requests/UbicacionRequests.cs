namespace Backend.Dtos.Requests;

/// <summary>Un lugar nuevo dentro de un almacén: un piso, un pasillo, un estante...</summary>
public class CrearUbicacionRequest
{
    /// <summary>El punto que lo va a contener. Sin valor, queda en la raíz del almacén (un piso, por ejemplo).</summary>
    public int? PadreId { get; set; }

    /// <summary>PISO, ZONA, PASILLO, ESTANTE, NIVEL, POSICION u OTRO.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>El código corto de este punto: "P1", "A", "03". No se repite entre hermanos.</summary>
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
/// Crear varios lugares seguidos de una vez: los estantes E01 a E20 de un pasillo, las posiciones 01 a 12 de un estante.
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
