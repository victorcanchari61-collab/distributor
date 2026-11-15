namespace Backend.Models;

/// <summary>
/// Qué es un punto dentro del almacén. Son dos, de grande a chico: el PISO y el CUARTO que hay en cada piso.
/// Un piso va directo en el almacén; un cuarto va adentro de un piso (o directo en el almacén, si no hay pisos).
/// </summary>
public static class TipoUbicacion
{
    public const string Piso = "PISO";
    public const string Cuarto = "CUARTO";

    public static readonly string[] Todos = [Piso, Cuarto];

    public static string Etiqueta(string tipo) => tipo switch
    {
        Piso => "Piso",
        Cuarto => "Lugar",
        _ => tipo,
    };
}

/// <summary>
/// Un lugar dentro de un almacén: un piso o un cuarto.
///
/// Forman un árbol: el piso 1 tiene los lugares 01 y 02. Cada punto lleva su código
/// y la "ruta" (los códigos de arriba hacia abajo, unidos con guion: P1-01) es como se nombra y se
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

    /// <summary>El código corto de este punto ("P1", "01"). No se repite entre hermanos.</summary>
    public string Codigo { get; set; } = string.Empty;

    /// <summary>Un nombre para leerlo ("Primer piso", "Cuarto de abarrotes").</summary>
    public string? Nombre { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    // --- Dónde está dibujado en el plano de su piso (en celdas de la cuadrícula). Nulo: todavía no se dibujó. ---
    // Solo los lugares de adentro (no los pisos: cada piso ES un plano).

    public int? PlanoX { get; set; }
    public int? PlanoY { get; set; }
    public int? PlanoAncho { get; set; }
    public int? PlanoAlto { get; set; }
}

/// <summary>El tamaño de la cuadrícula del plano de cada piso, en celdas.</summary>
public static class Plano
{
    public const int Columnas = 24;
    public const int Filas = 14;
}

/// <summary>Lo que se dibuja en un plano y no guarda mercadería: por dónde se camina o se sube.</summary>
public static class TipoElementoPlano
{
    public const string Pasillo = "PASILLO";
    public const string Escalera = "ESCALERA";

    public static readonly string[] Todos = [Pasillo, Escalera];
}

/// <summary>
/// Un pasillo o una escalera dibujados en el plano de un piso. No son lugares: no tienen código ni se les pone
/// mercadería, pero sin ellos el plano no se parece al almacén y cuesta orientarse.
/// </summary>
public class ElementoPlano
{
    public int Id { get; set; }

    public int AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    /// <summary>El piso en cuyo plano está. Nulo: el almacén no usa pisos y tiene un solo plano.</summary>
    public int? PisoId { get; set; }
    public UbicacionAlmacen? Piso { get; set; }

    public string Tipo { get; set; } = TipoElementoPlano.Pasillo;
    public string Nombre { get; set; } = string.Empty;

    public int X { get; set; }
    public int Y { get; set; }
    public int Ancho { get; set; }
    public int Alto { get; set; }

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
