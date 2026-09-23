namespace Backend.Models;

/// <summary>
/// Producto del catalogo.
///
/// El stock de un producto se lleva SIEMPRE en su unidad base: kilos para el
/// azucar, unidades (botellas) para el aceite. Comprar un saco de 50 suma 50
/// kilos y vender 3 kilos resta 3, sin importar en que presentacion se hizo la
/// operacion. Las equivalencias viven en <see cref="ProductoPresentacion"/>.
///
/// Cada medida de un envasado es un producto distinto: "Aceite Primor 1 L" y
/// "Aceite Primor 900 ml" son dos productos, porque tienen stock y precio
/// propios. Lo que comparten es marca y categoria.
/// </summary>
public class Producto
{
    public int Id { get; set; }

    /// <summary>Codigo interno con el que se busca el producto. No se repite.</summary>
    public string Codigo { get; set; } = string.Empty;

    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }

    public int? CategoriaId { get; set; }
    public Categoria? Categoria { get; set; }

    public int? MarcaId { get; set; }
    public Marca? Marca { get; set; }

    /// <summary>Unidad en la que se guarda el stock: KG, UND, LT.</summary>
    public int UnidadBaseId { get; set; }
    public UnidadMedida? UnidadBase { get; set; }

    /// <summary>
    /// Cuanto contiene el envase, para productos envasados: 900 junto a la
    /// unidad ML. Es informativo — sirve para comparar precio por litro — y no
    /// interviene en el stock.
    /// </summary>
    public decimal? Contenido { get; set; }

    public int? ContenidoUnidadId { get; set; }
    public UnidadMedida? ContenidoUnidad { get; set; }

    /// <summary>
    /// Lo que SUELE costar una unidad base, para tenerlo a mano al cotizar y
    /// al recibir mercaderia.
    ///
    /// Es una referencia tuya, NO el costo del inventario: ese lo fija cada
    /// entrada, porque el proveedor sube y baja el precio y pueden convivir
    /// varios costos del mismo producto. Sirve como valor sugerido cuando una
    /// entrada pide costo, y para ver el margen de una lista de precios sin
    /// tener stock todavia.
    /// </summary>
    public decimal? CostoReferencia { get; set; }

    /// <summary>
    /// A cuánto SUELE venderse una unidad base.
    ///
    /// Es el precio de respaldo: cuando el pedido no lleva lista de precios, o la lista elegida no
    /// tiene cargada esa presentación, es este el que sale. Así ningún producto se vende en cero
    /// por no haber terminado de armar las listas.
    ///
    /// La lista MANDA sobre él: si la lista tiene precio para esa presentación y esa cantidad, se
    /// cobra el de la lista. Este es el piso común y la referencia al armar una lista nueva.
    /// </summary>
    public decimal? PrecioReferencia { get; set; }

    /// <summary>
    /// Cuánto pesa UNA unidad base, en kilos.
    ///
    /// De aquí sale el peso de cualquier cantidad sin tener que anotarlo en cada presentación: una
    /// caja de 12 botellas de 0.92 kg pesa 11.04, y un pedido de 10 cajas, 110.4. Sirve para saber
    /// qué carga lleva el camión. Vacío en lo que no se pesa.
    /// </summary>
    public decimal? PesoUnidadBase { get; set; }

    /// <summary>
    /// Si el producto paga IGV. La mayoría sí — los exonerados (varios
    /// alimentos de primera necesidad) son la excepción.
    ///
    /// El <see cref="PrecioReferencia"/> y los precios de presentación YA
    /// incluyen el IGV cuando el producto es afecto: se cobra tal cual se
    /// escribió, sin sumarle nada encima. Este campo no cambia cómo se cobra
    /// — es para separar el IGV al momento de reportar o emitir un
    /// comprobante.
    /// </summary>
    public bool AfectoIgv { get; set; }

    /// <summary>Servicios y similares no descuentan stock.</summary>
    public bool ControlaStock { get; set; } = true;

    /// <summary>Aviso de reposicion, en unidad base.</summary>
    public decimal StockMinimo { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<ProductoPresentacion> Presentaciones { get; set; } = [];
}
