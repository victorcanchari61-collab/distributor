namespace Backend.Models;

/// <summary>
/// Politica de precios: Mayorista, Minorista, Bodega. Un cliente compra con la
/// lista que tenga asignada; si no tiene, con la predeterminada.
/// </summary>
public class ListaPrecio
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }

    /// <summary>La que se usa cuando el cliente no tiene lista propia.</summary>
    public bool EsPredeterminada { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<PrecioProducto> Precios { get; set; } = [];
}

/// <summary>
/// Precio de una presentacion dentro de una lista.
///
/// El precio se pone POR PRESENTACION, no por producto: asi el saco sale mas
/// barato por kilo que vender el kilo suelto, que es como funciona el negocio.
///
///   Azucar, lista Minorista
///     Kilo         S/ 4.50   -> 4.50 el kilo
///     Bolsa 5 kg   S/ 21.00  -> 4.20 el kilo
///     Saco 50 kg   S/ 195.00 -> 3.90 el kilo
///
/// <see cref="CantidadMinima"/> permite ademas un escalon dentro de la misma
/// lista: desde 10 sacos, cada saco a S/ 190.
/// </summary>
public class PrecioProducto
{
    public int Id { get; set; }

    public int ListaPrecioId { get; set; }
    public ListaPrecio? ListaPrecio { get; set; }

    public int PresentacionId { get; set; }
    public ProductoPresentacion? Presentacion { get; set; }

    /// <summary>Precio de UNA presentacion completa: un saco, una caja, un kilo.</summary>
    public decimal Precio { get; set; }

    /// <summary>
    /// Desde cuantas presentaciones aplica este precio. 1 es el precio normal;
    /// un registro con 10 es el escalon por volumen.
    /// </summary>
    public decimal CantidadMinima { get; set; } = 1m;

    public bool Activo { get; set; } = true;
    public DateTime FechaActualizacion { get; set; } = DateTime.UtcNow;
}
