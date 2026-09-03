/// Una linea de una orden de compra o de una compra directa.
class LineaCompra {
  const LineaCompra({
    required this.id,
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.unidadBase,
    this.presentacionId,
    this.presentacion,
    required this.cantidadPresentacion,
    required this.cantidad,
    required this.costoUnitario,
    required this.costoTotal,
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
  final double costoUnitario;
  final double costoTotal;

  factory LineaCompra.desdeJson(Map<String, dynamic> json) => LineaCompra(
    id: json['id'] as int,
    productoId: json['productoId'] as int,
    codigo: json['codigo'] as String? ?? '',
    producto: json['producto'] as String? ?? '',
    unidadBase: json['unidadBase'] as String? ?? '',
    presentacionId: json['presentacionId'] as int?,
    presentacion: json['presentacion'] as String?,
    cantidadPresentacion: (json['cantidadPresentacion'] as num?)?.toDouble() ?? 0,
    cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
    costoUnitario: (json['costoUnitario'] as num?)?.toDouble() ?? 0,
    costoTotal: (json['costoTotal'] as num?)?.toDouble() ?? 0,
  );
}

class EstadoOrdenCompra {
  const EstadoOrdenCompra._();
  static const pendiente = 'PENDIENTE';
  static const confirmada = 'CONFIRMADA';
  static const anulada = 'ANULADA';
}

/// Lo que se le pide a un proveedor: cuando lo confirma, nace una Compra.
class OrdenCompra {
  const OrdenCompra({
    required this.id,
    required this.numero,
    required this.proveedorId,
    required this.proveedor,
    required this.fecha,
    this.fechaEsperada,
    required this.estado,
    this.observacion,
    this.usuario,
    required this.total,
    required this.detalle,
  });

  final int id;
  final String numero;
  final int proveedorId;
  final String proveedor;
  final DateTime fecha;
  final DateTime? fechaEsperada;

  /// PENDIENTE, CONFIRMADA o ANULADA.
  final String estado;
  final String? observacion;
  final String? usuario;
  final double total;
  final List<LineaCompra> detalle;

  String get buscable => '$numero $proveedor'.toLowerCase();

  factory OrdenCompra.desdeJson(Map<String, dynamic> json) => OrdenCompra(
    id: json['id'] as int,
    numero: json['numero'] as String? ?? '',
    proveedorId: json['proveedorId'] as int,
    proveedor: json['proveedor'] as String? ?? '',
    fecha: DateTime.parse(json['fecha'] as String),
    fechaEsperada: json['fechaEsperada'] == null
        ? null
        : DateTime.parse(json['fechaEsperada'] as String),
    estado: json['estado'] as String? ?? EstadoOrdenCompra.pendiente,
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    detalle: (json['detalle'] as List? ?? const [])
        .map((e) => LineaCompra.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}
