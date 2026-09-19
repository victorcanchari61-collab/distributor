import '../../../compartido/fechas.dart';

/// Una linea de un pedido o de una nota de venta.
class LineaVenta {
  const LineaVenta({
    required this.id,
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.unidadBase,
    this.presentacionId,
    this.presentacion,
    required this.cantidadPresentacion,
    required this.cantidad,
    required this.precioUnitario,
    required this.precioPresentacion,
    required this.subtotal,
    this.anulado = false,
  });

  final int id;
  final int productoId;
  final String codigo;
  final String producto;
  final String unidadBase;

  final int? presentacionId;
  final String? presentacion;
  final double cantidadPresentacion;

  /// En unidad base.
  final double cantidad;

  /// Por unidad base: derivado, para margenes y reportes.
  final double precioUnitario;

  /// Lo que se acordó por cada presentación: S/ 212.50 el saco.
  ///
  /// Es el precio que se cobra y el que se muestra. El de unidad base sale de
  /// dividirlo entre el factor, y multiplicarlo de vuelta no lo devuelve:
  /// 13.60 entre 3 kilos son 4.5333, y por 3 da 13.5999.
  final double precioPresentacion;

  final double subtotal;

  /// Se quitó del pedido al editarlo: no cuenta para el total ni se entrega,
  /// pero la fila se conserva para no perder su historial.
  final bool anulado;

  /// Cuántas unidades base trae una presentación de esta línea.
  double get factor => cantidadPresentacion > 0 ? cantidad / cantidadPresentacion : 1;

  factory LineaVenta.desdeJson(Map<String, dynamic> json) => LineaVenta(
    id: json['id'] as int,
    productoId: json['productoId'] as int,
    codigo: json['codigo'] as String? ?? '',
    producto: json['producto'] as String? ?? '',
    unidadBase: json['unidadBase'] as String? ?? '',
    presentacionId: json['presentacionId'] as int?,
    presentacion: json['presentacion'] as String?,
    cantidadPresentacion: (json['cantidadPresentacion'] as num?)?.toDouble() ?? 0,
    cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
    precioUnitario: (json['precioUnitario'] as num?)?.toDouble() ?? 0,
    precioPresentacion: (json['precioPresentacion'] as num?)?.toDouble() ?? 0,
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    anulado: json['anulado'] as bool? ?? false,
  );
}

/// En qué quedaron el vendedor y el cliente al tomar el pedido.
///
/// Lo lee el repartidor al llegar: si deja la mercadería solo contra el dinero
/// o si va fiada. No mueve plata por sí sola —el cobro se registra al
/// entregar—: es el acuerdo, escrito.
class CondicionPago {
  const CondicionPago._();
  static const contado = 'CONTADO';
  static const credito = 'CREDITO';
}

class EstadoPedido {
  const EstadoPedido._();
  static const pendiente = 'PENDIENTE';
  static const confirmado = 'CONFIRMADO';
  static const anulado = 'ANULADO';
}

/// Lo que pidio un cliente, antes de que exista una venta firme. Confirmarlo
/// es despacharlo: ahi nace la NotaVenta correspondiente, que es la que
/// descuenta el stock — el pedido nunca lo toca.
class Pedido {
  const Pedido({
    required this.id,
    required this.numero,
    required this.clienteId,
    required this.cliente,
    this.listaPrecioId,
    this.listaPrecio,
    this.condicionPago = CondicionPago.contado,
    required this.fecha,
    required this.estado,
    this.observacion,
    this.usuario,
    required this.reservaStock,
    this.almacenId,
    this.almacen,
    this.notaVentaNumero,
    this.noEntregadoMotivo,
    this.noEntregadoObservacion,
    required this.total,
    required this.detalle,
  });

  final int id;
  final String numero;
  final int clienteId;
  final String cliente;

  final int? listaPrecioId;
  final String? listaPrecio;

  /// CONTADO o CREDITO: lo acordado con el cliente.
  final String condicionPago;

  final DateTime fecha;

  /// PENDIENTE, CONFIRMADO o ANULADO.
  final String estado;
  final String? observacion;
  final String? usuario;

  /// Si aparta stock de [almacenId] mientras el pedido siga Pendiente.
  final bool reservaStock;
  final int? almacenId;
  final String? almacen;

  /// El número de la venta que nació de confirmarlo, si ya se convirtió.
  final String? notaVentaNumero;

  /// Por qué no se entregó, si el repartidor lo marcó como no entregado. El
  /// pedido sigue Pendiente: puede reintentarse o anularse.
  final String? noEntregadoMotivo;
  final String? noEntregadoObservacion;

  final double total;
  final List<LineaVenta> detalle;

  String get buscable => '$numero $cliente'.toLowerCase();

  factory Pedido.desdeJson(Map<String, dynamic> json) => Pedido(
    id: json['id'] as int,
    numero: json['numero'] as String? ?? '',
    clienteId: json['clienteId'] as int,
    cliente: json['cliente'] as String? ?? '',
    listaPrecioId: json['listaPrecioId'] as int?,
    condicionPago: json['condicionPago'] as String? ?? CondicionPago.contado,
    listaPrecio: json['listaPrecio'] as String?,
    fecha: fechaDeJson(json['fecha'] as String),
    estado: json['estado'] as String? ?? EstadoPedido.pendiente,
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    reservaStock: json['reservaStock'] as bool? ?? false,
    almacenId: json['almacenId'] as int?,
    almacen: json['almacen'] as String?,
    notaVentaNumero: json['notaVentaNumero'] as String?,
    noEntregadoMotivo: json['noEntregadoMotivo'] as String?,
    noEntregadoObservacion: json['noEntregadoObservacion'] as String?,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    detalle: (json['detalle'] as List? ?? const [])
        .map((e) => LineaVenta.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}
