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
    required this.subtotal,
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
  final double precioUnitario;
  final double subtotal;

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
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
  );
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
    required this.fecha,
    required this.estado,
    this.observacion,
    this.usuario,
    required this.total,
    required this.detalle,
  });

  final int id;
  final String numero;
  final int clienteId;
  final String cliente;

  final int? listaPrecioId;
  final String? listaPrecio;

  final DateTime fecha;

  /// PENDIENTE, CONFIRMADO o ANULADO.
  final String estado;
  final String? observacion;
  final String? usuario;
  final double total;
  final List<LineaVenta> detalle;

  String get buscable => '$numero $cliente'.toLowerCase();

  factory Pedido.desdeJson(Map<String, dynamic> json) => Pedido(
    id: json['id'] as int,
    numero: json['numero'] as String? ?? '',
    clienteId: json['clienteId'] as int,
    cliente: json['cliente'] as String? ?? '',
    listaPrecioId: json['listaPrecioId'] as int?,
    listaPrecio: json['listaPrecio'] as String?,
    fecha: DateTime.parse(json['fecha'] as String),
    estado: json['estado'] as String? ?? EstadoPedido.pendiente,
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    detalle: (json['detalle'] as List? ?? const [])
        .map((e) => LineaVenta.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}
