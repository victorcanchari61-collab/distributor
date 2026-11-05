namespace Backend.Models;

/// <summary>
/// Qué es un punto dentro del almacén. Son tres, de grande a chico: el PISO, el CUARTO que hay en cada piso y,
/// si hace falta, el ESTANTE dentro del cuarto. Es una etiqueta: no obliga ningún orden entre ellos (una casa de
/// un solo piso o un cuarto sin estantes también sirve).
/// </summary>
public static class TipoUbicacion
{
    public const string Piso = "PISO";
    public const string Cuarto = "CUARTO";
    public const string Estante = "ESTANTE";

    public static readonly string[] Todos = [Piso, Cuarto, Estante];

    public static string Etiqueta(string tipo) => tipo switch
    {
        Piso => "Piso",
        Cuarto => "Cuarto",
        Estante => "Estante",
        _ => tipo,
    };
}

/// <summary>
/// Un lugar dentro de un almacén: un piso, un cuarto, un estante.
///
/// Forman un árbol: el piso 1 tiene el cuarto C1, que tiene el estante E03. Cada punto lleva su código
/// y la "ruta" (los códigos de arriba hacia abajo, unidos con guion: P1-C1-E03) es como se nombra y se
/// busca el lugar. Hoy sirve para decir DÓNDE está un producto; el stock sigue contándose por almacén.
/// </summary>
public class UbicacionAlmacen
{
    public int Id { get; set; }

    public int AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    /// <summary>El punto que lo contiene (el piso, para un cuarto). Nulo: está en la raíz del almacén.</summary>
    public int? PadreId { get; set; }
    public UbicacionAlmacen? Padre { get; set; }

    public string Tipo { get; set; } = TipoUbicacion.Cuarto;

    /// <summary>El código corto de este punto ("P1", "C1", "E03"). No se repite entre hermanos.</summary>
    public string Codigo { get; set; } = string.Empty;

    /// <summary>Un nombre para leerlo ("Primer piso", "Cuarto de abarrotes").</summary>
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
