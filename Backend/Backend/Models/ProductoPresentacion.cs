namespace Backend.Models;

/// <summary>
/// Una forma de comprar o vender el producto, con su equivalencia en unidad
/// base. El <see cref="Factor"/> es la pieza central del modelo:
///
///   Azucar rubia, unidad base KG
///     Kilo        factor 1     venta
///     Bolsa 5 kg  factor 5     venta   (dos bolsas son 10 kg)
///     Saco 43 kg  factor 43    compra y venta
///     Saco 50 kg  factor 50    compra y venta
///
///   Aceite Primor 1 L, unidad base UND (botella)
///     Unidad      factor 1     venta
///     Caja x12    factor 12    compra y venta
///
///   Aceite Primor 1/4, unidad base UND
///     Caja x24    factor 24    compra
///
/// Comprar 2 sacos de 50 mueve 100 kg; vender 3 kilos mueve 3. Toda operacion
/// guarda la presentacion usada y la cantidad ya convertida, para que el stock
/// cuadre y el documento siga diciendo "2 sacos".
/// </summary>
public class ProductoPresentacion
{
    public int Id { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int UnidadId { get; set; }
    public UnidadMedida? Unidad { get; set; }

    /// <summary>Como se lee en pantalla: "Saco 50 kg", "Caja x 12".</summary>
    public string Nombre { get; set; } = string.Empty;

    /// <summary>
    /// Cuantas unidades base equivale. Siempre mayor que cero. La presentacion
    /// base del producto tiene factor 1 y no se puede borrar.
    /// </summary>
    public decimal Factor { get; set; } = 1m;

    /// <summary>Se puede comprar en esta presentacion.</summary>
    public bool EsCompra { get; set; } = true;

    /// <summary>Se puede vender en esta presentacion.</summary>
    public bool EsVenta { get; set; } = true;

    /// <summary>La que sale elegida en un pedido nuevo.</summary>
    public bool PredeterminadaVenta { get; set; }

    /// <summary>La que sale elegida en una orden de compra nueva.</summary>
    public bool PredeterminadaCompra { get; set; }

    public string? CodigoBarras { get; set; }

    public bool Activo { get; set; } = true;
}
