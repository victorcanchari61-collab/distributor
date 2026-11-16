using System.Text.Json;
using System.Text.Json.Serialization;

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

    /// <summary>
    /// Las partes extra del lugar, en JSON (una lista de rectángulos como el principal). Así un cuarto toma forma de L
    /// y rodea una escalera. Nulo: el lugar es solo su rectángulo principal. Se lee con <see cref="Plano.LeerPartes"/>.
    /// </summary>
    public string? PlanoPartes { get; set; }

    /// <summary>
    /// Doble altura: el piso hasta donde el lugar está abierto, sin suelo encima (un depósito alto). En los pisos de
    /// arriba hasta este, su mismo espacio es un vacío donde no se dibuja nada. Nulo: solo ocupa su piso.
    /// </summary>
    public int? PlanoHastaPisoId { get; set; }
    public UbicacionAlmacen? PlanoHastaPiso { get; set; }
}

/// <summary>El tamaño de la cuadrícula del plano de cada piso, en celdas.</summary>
public static class Plano
{
    public const int Columnas = 24;
    public const int Filas = 14;

    /// <summary>Cuántas partes extra puede tener un lugar: más que esto es dibujar celda por celda.</summary>
    public const int MaximoPartes = 30;

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    /// <summary>Las partes extra guardadas en <see cref="UbicacionAlmacen.PlanoPartes"/>; vacío si no tiene o no se leen.</summary>
    public static List<RectPlano> LeerPartes(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return [];
        try
        {
            return JsonSerializer.Deserialize<List<RectPlano>>(json, Json) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }

    public static string? EscribirPartes(IReadOnlyCollection<RectPlano> partes) =>
        partes.Count == 0 ? null : JsonSerializer.Serialize(partes, Json);

    /// <summary>El número de un piso por su código (P2 → 2); los que no siguen la serie van al final.</summary>
    public static int NumeroDePiso(string codigo) =>
        codigo.Length > 1 && char.ToUpperInvariant(codigo[0]) == 'P' && int.TryParse(codigo[1..], out var n) ? n : int.MaxValue;

    /// <summary>Los pisos de abajo hacia arriba: por el número de su código (P2 antes que P10).</summary>
    public static List<int> OrdenarPisos(IEnumerable<(int Id, string Codigo)> pisos) =>
        pisos.OrderBy(p => NumeroDePiso(p.Codigo)).ThenBy(p => p.Id).Select(p => p.Id).ToList();

    /// <summary>
    /// Los pisos que ocupa algo que va de un piso a otro (una escalera, una doble altura), de abajo hacia arriba y
    /// con los del medio. Sin el otro piso, solo el suyo; en un almacén sin pisos, su único plano (nulo).
    /// </summary>
    public static List<int?> PisosEntre(int? desde, int? hasta, IReadOnlyList<int> orden)
    {
        if (desde is not int a || hasta is not int b) return [desde];
        var i = orden.ToList().IndexOf(a);
        var j = orden.ToList().IndexOf(b);
        if (i < 0 || j < 0) return [desde];
        var (menor, mayor) = i <= j ? (i, j) : (j, i);
        return orden.Skip(menor).Take(mayor - menor + 1).Select(p => (int?)p).ToList();
    }

    /// <summary>Si el piso `arriba` está encima de `piso` (lo que pide una doble altura).</summary>
    public static bool EstaEncima(int piso, int arriba, IReadOnlyList<int> orden)
    {
        var lista = orden.ToList();
        var i = lista.IndexOf(piso);
        var j = lista.IndexOf(arriba);
        return i >= 0 && j > i;
    }

    /// <summary>Si todas las partes forman una sola figura: desde la primera se llega a cada una tocándose por un lado.</summary>
    public static bool Conectadas(IReadOnlyList<RectPlano> partes)
    {
        if (partes.Count <= 1) return true;
        var visto = new bool[partes.Count];
        var pila = new Stack<int>([0]);
        visto[0] = true;
        while (pila.Count > 0)
        {
            var i = pila.Pop();
            for (var j = 0; j < partes.Count; j++)
                if (!visto[j] && partes[i].Toca(partes[j]))
                {
                    visto[j] = true;
                    pila.Push(j);
                }
        }
        return visto.All(v => v);
    }
}

/// <summary>Un rectángulo de la cuadrícula del plano, en celdas.</summary>
public record RectPlano(int X, int Y, int Ancho, int Alto)
{
    /// <summary>Se enciman: comparten al menos una celda.</summary>
    public bool Choca(RectPlano o) => X < o.X + o.Ancho && o.X < X + Ancho && Y < o.Y + o.Alto && o.Y < Y + Alto;

    /// <summary>Se tocan por un lado (comparten un tramo de borde); tocarse solo por una esquina no cuenta.</summary>
    public bool Toca(RectPlano o) =>
        ((X + Ancho == o.X || o.X + o.Ancho == X) && Y < o.Y + o.Alto && o.Y < Y + Alto)
        || ((Y + Alto == o.Y || o.Y + o.Alto == Y) && X < o.X + o.Ancho && o.X < X + Ancho);

    /// <summary>Entra entero en la cuadrícula y mide al menos una celda. No se guarda: se calcula.</summary>
    [JsonIgnore]
    public bool Cabe => X >= 0 && Y >= 0 && Ancho >= 1 && Alto >= 1 && X + Ancho <= Plano.Columnas && Y + Alto <= Plano.Filas;
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

    /// <summary>
    /// Solo escaleras: el piso al que llega. Una escalera une pisos y ocupa el mismo lugar en todos los que cruza,
    /// desde <see cref="PisoId"/> hasta este (de P1 a P3 pasa por P2). Nulo: una escalera de antes, sin otro piso.
    /// </summary>
    public int? HastaPisoId { get; set; }
    public UbicacionAlmacen? HastaPiso { get; set; }

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
