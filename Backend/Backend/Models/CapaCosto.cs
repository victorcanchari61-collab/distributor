namespace Backend.Models;

/// <summary>De donde salio la mercaderia de una capa.</summary>
public static class OrigenCapa
{
    /// <summary>Lo que ya habia el dia que arranco el sistema.</summary>
    public const string SaldoInicial = "SALDO_INICIAL";

    /// <summary>Entro por una compra.</summary>
    public const string Compra = "COMPRA";

    /// <summary>Ajuste manual de inventario.</summary>
    public const string Ajuste = "AJUSTE";

    public static readonly string[] Todos = [SaldoInicial, Compra, Ajuste];
}

/// <summary>
/// Una entrada de mercaderia con SU costo.
///
/// El costo no es un dato del producto: es un dato de cada compra. Si el saco
/// de azucar costo 170 en setiembre y 180 en octubre, y todavia queda stock del
/// primero, los dos costos conviven. Guardarlo en el producto obligaria a pisar
/// uno con otro y la ganancia saldria mal.
///
///   Capa 1   50 kg   quedan 50   S/ 3.40 el kg   (saco a 170)
///   Capa 2   50 kg   quedan 50   S/ 3.60 el kg   (saco a 180)
///
/// Al vender 60 kg se consumen los 50 de la capa 1 y 10 de la capa 2, y el
/// costo de esa venta es 50x3.40 + 10x3.60 = 206. Primero se gasta la capa mas
/// antigua (PEPS), que es como sale la mercaderia del almacen.
///
/// El costo SIEMPRE se guarda por unidad base: comprar un saco de 50 kg a 170
/// guarda 3.40 por kilo, para que vender 3 kilos sueltos sepa que costaron
/// 10.20. El flete se reparte antes de dividir.
/// </summary>
public class CapaCosto
{
    public int Id { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    /// <summary>Cuanto entro, en unidad base.</summary>
    public decimal CantidadInicial { get; set; }

    /// <summary>Cuanto queda sin vender, en unidad base. Cero = capa agotada.</summary>
    public decimal CantidadDisponible { get; set; }

    /// <summary>Cuanto costo cada unidad base, flete incluido.</summary>
    public decimal CostoUnitario { get; set; }

    /// <summary>SALDO_INICIAL / COMPRA / AJUSTE. Ver <see cref="OrigenCapa"/>.</summary>
    public string Origen { get; set; } = OrigenCapa.Compra;

    /// <summary>Numero de la factura o guia con la que entro.</summary>
    public string? Referencia { get; set; }

    /// <summary>
    /// Fecha de la entrada. Es la que ordena el consumo: primero se gasta la
    /// mas antigua.
    /// </summary>
    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
