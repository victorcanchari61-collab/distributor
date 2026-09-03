namespace Backend.Models;

/// <summary>
/// Donde se guarda la mercaderia. El sistema arranca con uno principal: quien
/// tenga un solo deposito nunca lo elige, y quien abra otro no tiene que
/// rehacer nada porque el stock ya se lleva por almacen.
/// </summary>
public class Almacen
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }

    /// <summary>El que se usa cuando no se indica otro.</summary>
    public bool EsPrincipal { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}

/// <summary>Si el motivo suma o resta stock.</summary>
public static class TipoMovimiento
{
    public const string Entrada = "ENTRADA";
    public const string Salida = "SALIDA";

    public static readonly string[] Todos = [Entrada, Salida];
}

/// <summary>Ids sembrados de los motivos del sistema.</summary>
public static class Motivos
{
    public const int CargaInicial = 1;
    public const int Compra = 2;
    public const int Venta = 3;
    public const int VentaAnulada = 4;
    public const int CompraAnulada = 5;
    public const int DevolucionProveedor = 6;
    public const int TransferenciaSalida = 7;
    public const int TransferenciaIngreso = 8;
    public const int SobranteConteo = 9;
    public const int FaltanteConteo = 10;
    public const int Merma = 11;
    public const int Rotura = 12;
    public const int Vencimiento = 13;
    public const int PrestamoDado = 14;
    public const int DevolucionPrestamoDado = 15;
    public const int PrestamoRecibido = 16;
    public const int DevolucionPrestamoRecibido = 17;
}

/// <summary>
/// Por que se movio el stock.
///
/// Hay dos clases y la diferencia es quien crea el movimiento:
///
///   - Del sistema: los crea un documento (una venta, una compra, una
///     anulacion). NO se ofrecen al hacer un ajuste a mano: si alguien pudiera
///     elegir "Venta" sin que exista la venta, el inventario quedaria
///     descuadrado y sin explicacion. Tampoco se editan ni se eliminan, porque
///     hay movimientos historicos apuntando a ellos.
///
///   - Manuales: los unicos elegibles en un ajuste. El usuario puede crear los
///     suyos (prestamo a otra bodega, consumo interno) diciendo si suman o
///     restan.
/// </summary>
public class MotivoMovimiento
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;

    /// <summary>ENTRADA o SALIDA. Ver <see cref="TipoMovimiento"/>.</summary>
    public string Tipo { get; set; } = TipoMovimiento.Entrada;

    /// <summary>Lo crea un documento; no se elige a mano, ni se borra.</summary>
    public bool DelSistema { get; set; }

    /// <summary>
    /// Si hay que declarar cuanto costo. Las entradas lo piden; las salidas
    /// NO, porque el costo ya venia con la mercaderia que sale.
    /// </summary>
    public bool PideCosto { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}

/// <summary>Estado de un documento de inventario.</summary>
public static class EstadoDocumento
{
    public const string Confirmado = "CONFIRMADO";
    public const string Anulado = "ANULADO";
}

/// <summary>Que clase de documento movio el stock.</summary>
public static class TipoDocumentoInventario
{
    public const string Ajuste = "AJUSTE";
    public const string Anulacion = "ANULACION";

    /// <summary>Mueve stock de un almacén propio a otro. AlmacenId es el origen.</summary>
    public const string Transferencia = "TRANSFERENCIA";

    /// <summary>Sale o entra mercadería de un tercero, fuera de mis almacenes.</summary>
    public const string Prestamo = "PRESTAMO";

    /// <summary>Devuelve, total o parcial, lo que se prestó o lo que prestaron.</summary>
    public const string DevolucionPrestamo = "DEVOLUCION_PRESTAMO";

    /// <summary>Mercadería que llega contra una Compra. AlmacenId es donde entra.</summary>
    public const string Recepcion = "RECEPCION";

    /// <summary>Mercadería que sale por una venta. AlmacenId es de donde sale.</summary>
    public const string NotaVenta = "NOTA_VENTA";
}

/// <summary>
/// El papel que respalda un movimiento: numero, fecha, almacen, motivo y quien
/// lo hizo.
///
/// Un documento confirmado NO se edita: se anula con otro documento que crea
/// los movimientos espejo. Editarlo dejaria el stock de hoy sin explicacion en
/// el historial.
/// </summary>
public class DocumentoInventario
{
    public int Id { get; set; }

    /// <summary>Correlativo visible: AJ-000001.</summary>
    public string Numero { get; set; } = string.Empty;

    /// <summary>AJUSTE o ANULACION.</summary>
    public string Tipo { get; set; } = TipoDocumentoInventario.Ajuste;

    /// <summary>En una transferencia, el almacén de origen. En todo lo demás, el único.</summary>
    public int AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    /// <summary>Solo en transferencias: el almacén que recibe.</summary>
    public int? AlmacenDestinoId { get; set; }
    public Almacen? AlmacenDestino { get; set; }

    /// <summary>Motivo "de cabecera", informativo: cada línea guarda el suyo.</summary>
    public int MotivoId { get; set; }
    public MotivoMovimiento? Motivo { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;
    public string Estado { get; set; } = EstadoDocumento.Confirmado;
    public string? Observacion { get; set; }

    /// <summary>Quien lo registro.</summary>
    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    /// <summary>Si este documento anula a otro, cual.</summary>
    public int? DocumentoAnuladoId { get; set; }
    public DocumentoInventario? DocumentoAnulado { get; set; }

    /// <summary>Solo en una recepción: la compra que se está descargando.</summary>
    public int? CompraId { get; set; }
    public Compra? Compra { get; set; }

    /// <summary>Solo en una salida de venta: la nota de venta que descarga.</summary>
    public int? NotaVentaId { get; set; }
    public NotaVenta? NotaVenta { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<MovimientoInventario> Movimientos { get; set; } = [];
}

/// <summary>
/// Una linea de stock que se movio. Es el kardex.
///
/// La cantidad se guarda SIEMPRE en unidad base, pero tambien se conserva en
/// que presentacion se hizo la operacion, para que el papel siga diciendo
/// "2 sacos" aunque el stock hable en kilos.
/// </summary>
public class MovimientoInventario
{
    public int Id { get; set; }

    public int DocumentoId { get; set; }
    public DocumentoInventario? Documento { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    public int MotivoId { get; set; }
    public MotivoMovimiento? Motivo { get; set; }

    /// <summary>ENTRADA o SALIDA, copiado del motivo al momento del movimiento.</summary>
    public string Tipo { get; set; } = TipoMovimiento.Entrada;

    /// <summary>En que presentacion se hizo: el saco, la caja.</summary>
    public int? PresentacionId { get; set; }
    public ProductoPresentacion? Presentacion { get; set; }

    /// <summary>Cuantas presentaciones, tal como se escribio.</summary>
    public decimal CantidadPresentacion { get; set; }

    /// <summary>La misma cantidad convertida a unidad base. Siempre positiva.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Costo por unidad base: declarado si entra, heredado si sale.</summary>
    public decimal CostoUnitario { get; set; }

    /// <summary>Cantidad x costo.</summary>
    public decimal CostoTotal { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    /// <summary>Movimiento que este revierte, cuando es una anulacion.</summary>
    public int? MovimientoOrigenId { get; set; }

    /// <summary>
    /// Solo en una recepción: la línea de la compra que este movimiento
    /// recibió. Al anular, es lo que permite descontar CantidadRecibida de
    /// la línea correcta sin tener que adivinar cuál era.
    /// </summary>
    public int? CompraDetalleId { get; set; }
    public CompraDetalle? CompraDetalle { get; set; }

    /// <summary>
    /// Solo en una salida de venta: la línea de la nota de venta que este
    /// movimiento descargó. Igual que CompraDetalleId, pero al revés.
    /// </summary>
    public int? NotaVentaDetalleId { get; set; }
    public NotaVentaDetalle? NotaVentaDetalle { get; set; }

    public List<ConsumoCapa> Consumos { get; set; } = [];
}

/// <summary>De donde salio la mercaderia de una capa.</summary>
public static class OrigenCapa
{
    public const string CargaInicial = "CARGA_INICIAL";
    public const string Compra = "COMPRA";
    public const string Ajuste = "AJUSTE";
    public const string Devolucion = "DEVOLUCION";
    public const string Transferencia = "TRANSFERENCIA";

    /// <summary>Mercadería de un tercero, prestada a la empresa.</summary>
    public const string Prestamo = "PRESTAMO";
}

/// <summary>
/// Una entrada de mercaderia con SU costo.
///
/// El costo no es un dato del producto: es un dato de cada entrada. Si el saco
/// costo 170 en setiembre y 180 en octubre, y todavia queda del primero, los
/// dos costos conviven.
///
///   Capa 1   50 kg   quedan 50   S/ 3.40 el kg
///   Capa 2   50 kg   quedan 50   S/ 3.60 el kg
///
/// Vender 60 kg consume los 50 de la capa 1 y 10 de la capa 2: costo 206. Se
/// gasta primero la mas antigua (PEPS), que es como sale del almacen.
/// </summary>
public class CapaCosto
{
    public int Id { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    /// <summary>Movimiento de entrada que la creo.</summary>
    public int MovimientoId { get; set; }
    public MovimientoInventario? Movimiento { get; set; }

    /// <summary>Cuanto entro, en unidad base.</summary>
    public decimal CantidadInicial { get; set; }

    /// <summary>Cuanto queda. Cero = capa agotada.</summary>
    public decimal CantidadDisponible { get; set; }

    /// <summary>Costo por unidad base, flete incluido.</summary>
    public decimal CostoUnitario { get; set; }

    /// <summary>Lote del proveedor o de fabricación, si se indicó.</summary>
    public string? Lote { get; set; }

    /// <summary>Cuándo vence esta capa. Solo informativo: no bloquea salidas.</summary>
    public DateTime? FechaVencimiento { get; set; }

    public string Origen { get; set; } = OrigenCapa.Compra;

    /// <summary>Ordena el consumo: primero se gasta la mas antigua.</summary>
    public DateTime Fecha { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Que capa alimento que salida, y cuanto.
///
/// Es la tabla que casi siempre falta y la que hace que anular funcione: sin
/// ella no se sabe a que costo devolver la mercaderia. Si vendiste con costo
/// 3.40 y hoy el stock esta a 3.60, la anulacion tiene que reponer a 3.40; si
/// repone a 3.60 se inventa utilidad de la nada.
/// </summary>
public class ConsumoCapa
{
    public int Id { get; set; }

    public int MovimientoId { get; set; }
    public MovimientoInventario? Movimiento { get; set; }

    public int CapaId { get; set; }
    public CapaCosto? Capa { get; set; }

    /// <summary>Cuanto se tomo de esa capa, en unidad base.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Costo de la capa en ese momento.</summary>
    public decimal CostoUnitario { get; set; }
}

/// <summary>Quién presta a quién.</summary>
public static class TipoPrestamo
{
    /// <summary>Sale mercadería propia hacia un tercero.</summary>
    public const string Dado = "DADO";

    /// <summary>Entra mercadería de un tercero.</summary>
    public const string Recibido = "RECIBIDO";

    public static readonly string[] Todos = [Dado, Recibido];
}

public static class EstadoPrestamo
{
    public const string Pendiente = "PENDIENTE";
    public const string Devuelto = "DEVUELTO";
}

/// <summary>
/// Mercadería que sale o entra desde fuera de la empresa, sin ser compra ni
/// venta: se presta y se espera de vuelta.
///
/// Se distingue de una transferencia en que la contraparte NO es un almacén
/// propio: es un tercero (otro negocio, un conocido), y por eso el prestamo
/// lleva quien es esa contraparte y si ya devolvio o le devolvieron.
///
/// Por dentro usa el mismo motor que todo lo demas: cada linea crea un
/// MovimientoInventario con su motivo (PrestamoDado/PrestamoRecibido), y la
/// devolucion consume o repone esas mismas capas — nunca stock generico —
/// para no mezclar mercaderia prestada con la comprada.
/// </summary>
public class Prestamo
{
    public int Id { get; set; }

    /// <summary>Correlativo visible: PR-000001.</summary>
    public string Numero { get; set; } = string.Empty;

    /// <summary>DADO o RECIBIDO. Ver <see cref="TipoPrestamo"/>.</summary>
    public string Tipo { get; set; } = TipoPrestamo.Dado;

    /// <summary>A quien se le presta, o quien presta. Texto libre.</summary>
    public string Contraparte { get; set; } = string.Empty;

    public int AlmacenId { get; set; }
    public Almacen? Almacen { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    /// <summary>PENDIENTE mientras falte devolver algo; DEVUELTO cuando ya no queda nada.</summary>
    public string Estado { get; set; } = EstadoPrestamo.Pendiente;

    public string? Observacion { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<PrestamoDetalle> Detalle { get; set; } = [];
}

/// <summary>Un producto dentro del préstamo, con cuánto ya se devolvió.</summary>
public class PrestamoDetalle
{
    public int Id { get; set; }

    public int PrestamoId { get; set; }
    public Prestamo? Prestamo { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int? PresentacionId { get; set; }
    public ProductoPresentacion? Presentacion { get; set; }

    /// <summary>Cómo se escribió: "2 Saco 50 kg".</summary>
    public decimal CantidadPresentacion { get; set; }

    /// <summary>En unidad base. Lo que salió o entró originalmente.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Cuánto de esta línea ya se devolvió, en unidad base.</summary>
    public decimal CantidadDevuelta { get; set; }

    /// <summary>Movimiento que registró el préstamo: de ahí sale el costo al devolver.</summary>
    public int MovimientoId { get; set; }
    public MovimientoInventario? Movimiento { get; set; }
}
