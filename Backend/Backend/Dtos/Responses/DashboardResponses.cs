namespace Backend.Dtos.Responses;

/// <summary>Un valor con nombre: una barra, una porción de dona.</summary>
public class DashItem
{
    public string Nombre { get; set; } = string.Empty;
    public decimal Valor { get; set; }

    /// <summary>Cuántos documentos o unidades hay detrás del valor, cuando importa.</summary>
    public int Cantidad { get; set; }
}

// ------------------------------------------------------------------ Ventas

public class DashTotalesVentas
{
    public decimal Importe { get; set; }
    public int Notas { get; set; }
    public int Clientes { get; set; }

    /// <summary>Lo que deja una venta en promedio.</summary>
    public decimal Ticket { get; set; }
}

public class DashDiaVenta
{
    public DateTime Fecha { get; set; }
    public decimal Importe { get; set; }
    public int Notas { get; set; }

    /// <summary>Lo vendido el mismo día del período anterior, para superponerlo.</summary>
    public decimal ImporteAnterior { get; set; }
}

/// <summary>Un día que se sale de lo normal de ese período.</summary>
public class DashAtipico
{
    /// <summary>Posición dentro de la serie.</summary>
    public int Indice { get; set; }

    /// <summary>PICO o CAIDA.</summary>
    public string Tipo { get; set; } = "PICO";
}

/// <summary>
/// Cómo va el mes en curso frente al pasado, y a dónde llega si sigue así.
///
/// La proyección respeta los días de la semana: si los domingos no se vende, no
/// se cuentan como días de venta. Sacar un promedio parejo los infla.
/// </summary>
public class DashMes
{
    public string Nombre { get; set; } = string.Empty;
    public int DiaActual { get; set; }
    public int DiasMes { get; set; }

    public decimal Acumulado { get; set; }
    public decimal Proyectado { get; set; }
    public decimal MesAnterior { get; set; }

    /// <summary>Lo que llevaba el mes pasado a este mismo día.</summary>
    public decimal MesAnteriorMismoPunto { get; set; }

    /// <summary>Lo acumulado día a día del mes en curso.</summary>
    public List<decimal> SerieActual { get; set; } = [];

    /// <summary>Lo acumulado día a día del mes pasado.</summary>
    public List<decimal> SerieAnterior { get; set; } = [];

    /// <summary>
    /// Lo que se espera acumular, un valor por día del mes. Vacío (null) hasta
    /// hoy; desde hoy arranca en lo acumulado para que la línea se una a la real.
    /// </summary>
    public List<decimal?> SerieProyeccion { get; set; } = [];
}

/// <summary>Un cliente dentro de la curva de Pareto.</summary>
public class DashPareto
{
    public string Nombre { get; set; } = string.Empty;
    public decimal Valor { get; set; }

    /// <summary>Qué parte del total llevan él y todos los de arriba, en %.</summary>
    public decimal Acumulado { get; set; }
}

/// <summary>Un casillero del mapa de calor: día de la semana × hora.</summary>
public class DashCalor
{
    /// <summary>0 = lunes … 6 = domingo.</summary>
    public int Dia { get; set; }

    public int Hora { get; set; }
    public decimal Importe { get; set; }
    public int Notas { get; set; }
}

public class DashboardVentasResponse
{
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }
    public bool SoloPropio { get; set; }

    public DashTotalesVentas Actual { get; set; } = new();
    public DashTotalesVentas Anterior { get; set; } = new();

    public List<DashDiaVenta> Serie { get; set; } = [];
    public List<DashAtipico> Atipicos { get; set; } = [];
    public DashMes Mes { get; set; } = new();

    public List<DashItem> PorVendedor { get; set; } = [];
    public List<DashItem> PorCategoria { get; set; } = [];
    public List<DashItem> PorFormaPago { get; set; } = [];
    public List<DashItem> TopProductos { get; set; } = [];
    public List<DashPareto> Pareto { get; set; } = [];

    /// <summary>Cuántos clientes hacen el 80 % de lo vendido.</summary>
    public int ClientesAl80 { get; set; }

    public int ClientesTotal { get; set; }
    public List<DashCalor> Calor { get; set; } = [];
}

// --------------------------------------------------------------- Ganancias

public class DashDiaGanancia
{
    public DateTime Fecha { get; set; }
    public decimal Importe { get; set; }
    public decimal Ganancia { get; set; }

    /// <summary>En %; null si ese día no hubo venta.</summary>
    public decimal? Margen { get; set; }
}

/// <summary>Un producto en la matriz margen × volumen.</summary>
public class DashProductoGanancia
{
    public string Nombre { get; set; } = string.Empty;
    public string Categoria { get; set; } = string.Empty;
    public decimal Importe { get; set; }
    public decimal Ganancia { get; set; }
    public decimal? Margen { get; set; }
}

public class DashboardGananciasResponse
{
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }
    public bool SoloPropio { get; set; }

    public decimal Importe { get; set; }
    public decimal Costo { get; set; }
    public decimal Ganancia { get; set; }
    public decimal? Margen { get; set; }

    public decimal GananciaAnterior { get; set; }
    public decimal? MargenAnterior { get; set; }

    public List<DashDiaGanancia> Serie { get; set; } = [];
    public List<DashProductoGanancia> Productos { get; set; } = [];

    /// <summary>La ganancia de cada categoría.</summary>
    public List<DashItem> PorCategoria { get; set; } = [];

    /// <summary>Productos que se vendieron sin costo conocido: su ganancia no es fiable.</summary>
    public int LineasSinCosto { get; set; }
}

// ---------------------------------------------------------------- Cobranza

public class DashDeudor
{
    public string Cliente { get; set; } = string.Empty;
    public decimal Saldo { get; set; }
    public int Notas { get; set; }

    /// <summary>Los días de la deuda más vieja: lo que decide el color.</summary>
    public int Dias { get; set; }
}

public class DashCobroDia
{
    public DateTime Fecha { get; set; }

    /// <summary>Uno por cada método de <see cref="DashboardCobranzaResponse.Metodos"/>, en ese orden.</summary>
    public List<decimal> Valores { get; set; } = [];
}

public class DashboardCobranzaResponse
{
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }

    public decimal TotalPorCobrar { get; set; }
    public int Cuentas { get; set; }
    public int Clientes { get; set; }

    /// <summary>La deuda repartida por antigüedad.</summary>
    public List<DashItem> Antiguedad { get; set; } = [];

    public List<DashDeudor> Deudores { get; set; } = [];

    public decimal CobradoPeriodo { get; set; }
    public List<string> Metodos { get; set; } = [];
    public List<DashCobroDia> Cobros { get; set; } = [];

    /// <summary>Lo vendido a crédito en el período, para compararlo con lo cobrado.</summary>
    public decimal CreditoOtorgado { get; set; }

    /// <summary>Día por día: lo fiado, lo cobrado de lo fiado y cuánto se debía al cierre.</summary>
    public List<DashDeudaDia> Evolucion { get; set; } = [];

    /// <summary>Lo que se debe hoy, por la ruta del cliente: a dónde mandar a cobrar.</summary>
    public List<DashItem> PorRuta { get; set; } = [];

    /// <summary>Lo cobrado en el período por quien lo registró (Cantidad = cobros).</summary>
    public List<DashItem> PorCobrador { get; set; } = [];

    /// <summary>Lo cobrado en el período por método de pago.</summary>
    public List<DashItem> PorMetodo { get; set; } = [];
}

/// <summary>Un día de la deuda de los clientes.</summary>
public class DashDeudaDia
{
    public DateTime Fecha { get; set; }

    /// <summary>Lo vendido a crédito ese día.</summary>
    public decimal Fiado { get; set; }

    /// <summary>Lo que se cobró ese día de ventas a crédito.</summary>
    public decimal Cobrado { get; set; }

    /// <summary>Lo que se debía al terminar el día.</summary>
    public decimal Saldo { get; set; }
}

// ----------------------------------------------------------------- Compras

/// <summary>Un proveedor al que se le debe.</summary>
public class DashAcreedor
{
    public string Proveedor { get; set; } = string.Empty;
    public decimal Saldo { get; set; }
    public int Compras { get; set; }

    /// <summary>Los días de la deuda más vieja: lo que decide el color.</summary>
    public int Dias { get; set; }
}

/// <summary>Lo comprado un día, al contado y a crédito.</summary>
public class DashCompraDia
{
    public DateTime Fecha { get; set; }
    public decimal Contado { get; set; }
    public decimal Credito { get; set; }
}

/// <summary>Cómo cambió el costo de un producto: su última compra del período contra la de antes.</summary>
public class DashCostoProducto
{
    public string Producto { get; set; } = string.Empty;

    /// <summary>La unidad base: el costo es por esa unidad.</summary>
    public string Unidad { get; set; } = string.Empty;

    public decimal CostoAnterior { get; set; }
    public decimal CostoActual { get; set; }

    /// <summary>En %: +8.5 es que subió, -3 que bajó.</summary>
    public decimal Variacion { get; set; }
}

public class DashboardComprasResponse
{
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }

    // --- Lo que se debe hoy: no depende del período, como Cuentas por pagar ---

    public decimal TotalPorPagar { get; set; }

    /// <summary>Cuántas compras tienen saldo.</summary>
    public int Cuentas { get; set; }

    /// <summary>A cuántos proveedores se les debe.</summary>
    public int Proveedores { get; set; }

    /// <summary>La deuda repartida por antigüedad, en los mismos tramos de Cobranza.</summary>
    public List<DashItem> Antiguedad { get; set; } = [];

    /// <summary>Los proveedores a los que más se les debe.</summary>
    public List<DashAcreedor> Acreedores { get; set; } = [];

    /// <summary>Mercadería comprada que todavía no llega (compras pendientes o recibidas en parte).</summary>
    public decimal PorRecibir { get; set; }

    // --- Lo del período ---

    public decimal Comprado { get; set; }

    /// <summary>Lo comprado en los mismos días justo antes, para comparar.</summary>
    public decimal CompradoAnterior { get; set; }

    /// <summary>Cuántas compras se registraron.</summary>
    public int Compras { get; set; }

    public decimal CompradoCredito { get; set; }

    public decimal PagadoPeriodo { get; set; }

    /// <summary>Los métodos con que se pagó, de más a menos usado.</summary>
    public List<string> Metodos { get; set; } = [];

    /// <summary>Lo pagado a proveedores por día; cada valor, uno por método en el orden de <see cref="Metodos"/>.</summary>
    public List<DashCobroDia> Pagos { get; set; } = [];

    /// <summary>Lo comprado por día, al contado y a crédito.</summary>
    public List<DashCompraDia> Serie { get; set; } = [];

    /// <summary>A quién se le compra más.</summary>
    public List<DashItem> PorProveedor { get; set; } = [];

    /// <summary>Qué se compra, por categoría.</summary>
    public List<DashItem> PorCategoria { get; set; } = [];

    /// <summary>Los productos cuyo costo más cambió.</summary>
    public List<DashCostoProducto> Costos { get; set; } = [];
}

// -------------------------------------------------------------- Inventario

public class DashCobertura
{
    public string Producto { get; set; } = string.Empty;
    public decimal Stock { get; set; }
    public string Unidad { get; set; } = string.Empty;

    /// <summary>Lo que sale por día en promedio, en unidad base.</summary>
    public decimal VentaDiaria { get; set; }

    /// <summary>Cuántos días dura lo que hay al ritmo actual.</summary>
    public decimal Dias { get; set; }
}

public class DashboardInventarioResponse
{
    public decimal ValorTotal { get; set; }
    public int Productos { get; set; }

    /// <summary>Los que antes se acaban, al ritmo al que se venden.</summary>
    public List<DashCobertura> Cobertura { get; set; } = [];

    /// <summary>Cuántos productos hay en cada estado de salud del stock.</summary>
    public List<DashItem> Salud { get; set; } = [];

    public List<DashItem> ValorPorCategoria { get; set; } = [];

    /// <summary>Plata parada en productos que no se venden desde hace un mes.</summary>
    public List<DashItem> Dormido { get; set; } = [];

    public decimal DormidoTotal { get; set; }

    /// <summary>Lo que vence, por ventanas de tiempo. Valorizado a costo.</summary>
    public List<DashItem> Vencimientos { get; set; } = [];
}

// ----------------------------------------------------------------- Reparto

public class DashDiaPedidos
{
    public DateTime Fecha { get; set; }
    public int Pendientes { get; set; }
    public int Confirmados { get; set; }
    public int Anulados { get; set; }
}

public class DashboardRepartoResponse
{
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }
    public bool SoloPropio { get; set; }

    public List<DashDiaPedidos> Serie { get; set; } = [];
    public List<DashItem> PorEstado { get; set; } = [];

    /// <summary>De lo pedido a lo entregado y cobrado, etapa por etapa.</summary>
    public List<DashItem> Embudo { get; set; } = [];

    /// <summary>Lo que no llegó completo, por motivo. Null si quien mira no puede ver Novedades.</summary>
    public List<DashItem>? NovedadesPorMotivo { get; set; }

    public decimal ImporteNovedades { get; set; }

    /// <summary>De lo entregado, qué % llegó completo, en %. Null si no hubo entregas.</summary>
    public decimal? EntregaCompleta { get; set; }
}
