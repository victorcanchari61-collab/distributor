namespace Backend.Models;

/// <summary>
/// Si un producto se puede vender —o comprar— en una presentación.
///
/// Cada presentación lleva sus dos marcas ("se compra", "se vende"), y la unidad base también:
/// hay productos que solo salen por caja y no por unidad suelta. La pantalla ya no ofrece lo que
/// está apagado, pero el servidor no se puede fiar de eso: un pedido armado a mano, o desde el
/// celular con datos viejos, llegaría igual.
/// </summary>
public static class DisponibilidadPresentacion
{
    public static bool SeVende(Producto producto, ProductoPresentacion? presentacion) =>
        Permite(producto, presentacion, p => p.EsVenta);

    public static bool SeCompra(Producto producto, ProductoPresentacion? presentacion) =>
        Permite(producto, presentacion, p => p.EsCompra);

    private static bool Permite(
        Producto producto, ProductoPresentacion? presentacion, Func<ProductoPresentacion, bool> marca)
    {
        if (presentacion is not null) return presentacion.Activo && marca(presentacion);

        // Sin presentación la línea va en unidad base, cuya fila es la de factor 1. Si el producto
        // no trae ninguna, no hay nada que la apague.
        var bases = producto.Presentaciones.Where(p => p.Factor == 1m && p.Activo).ToList();
        return bases.Count == 0 || bases.Any(marca);
    }
}
