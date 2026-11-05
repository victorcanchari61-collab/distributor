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
        Cuarto => "Cuarto",
        _ => tipo,
    };
}

/// <summary>
/// Un lugar dentro de un almacén: un piso o un cuarto.
///
/// Forman un árbol: el piso 1 tiene los cuartos C1 y C2. Cada punto lleva su código
/// y la "ruta" (los códigos de arriba hacia abajo, unidos con guion: P1-C1) es como se nombra y se
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

    /// <summary>El código corto de este punto ("P1", "C1"). No se repite entre hermanos.</summary>
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
