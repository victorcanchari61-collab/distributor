namespace Backend.Models;

/// <summary>Qué es un punto dentro del almacén. Es una etiqueta: no obliga ningún orden entre niveles.</summary>
public static class TipoUbicacion
{
    public const string Piso = "PISO";
    public const string Zona = "ZONA";
    public const string Pasillo = "PASILLO";
    public const string Estante = "ESTANTE";
    public const string Nivel = "NIVEL";
    public const string Posicion = "POSICION";
    public const string Otro = "OTRO";

    public static readonly string[] Todos = [Piso, Zona, Pasillo, Estante, Nivel, Posicion, Otro];

    public static string Etiqueta(string tipo) => tipo switch
    {
        Piso => "Piso",
        Zona => "Zona",
        Pasillo => "Pasillo",
        Estante => "Estante",
        Nivel => "Nivel",
        Posicion => "Posición",
        Otro => "Otro",
        _ => tipo,
    };
}

/// <summary>
/// Un lugar dentro de un almacén: un piso, un pasillo, un estante, una posición.
///
/// Forman un árbol: el piso 1 tiene el pasillo A, que tiene el estante 03. Cada punto lleva su código
/// y la "ruta" (los códigos de arriba hacia abajo, unidos con guion: P1-A-03) es como se nombra y se
/// busca el lugar. Hoy sirve para decir DÓNDE está un producto; el stock sigue contándose por almacén.
/// </summary>
public class UbicacionAlmacen
{
    public int Id { get; set; }

    public int AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    /// <summary>El punto que lo contiene (el piso, para un pasillo). Nulo: está en la raíz del almacén.</summary>
    public int? PadreId { get; set; }
    public UbicacionAlmacen? Padre { get; set; }

    public string Tipo { get; set; } = TipoUbicacion.Otro;

    /// <summary>El código corto de este punto ("P1", "A", "03"). No se repite entre hermanos.</summary>
    public string Codigo { get; set; } = string.Empty;

    /// <summary>Un nombre para leerlo ("Primer piso", "Pasillo de abarrotes").</summary>
    public string? Nombre { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}

/// <summary>Dónde se encuentra un producto dentro de un almacén. Un producto puede estar en varios puntos.</summary>
public class ProductoUbicacion
{
    public int Id { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int UbicacionId { get; set; }
    public UbicacionAlmacen? Ubicacion { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
