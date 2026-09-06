import 'pedido.dart';

class EstadoNotaVenta {
  const EstadoNotaVenta._();
  static const confirmada = 'CONFIRMADA';
  static const anulada = 'ANULADA';
}

/// Como se paga una venta al cliente.
class FormaPagoVenta {
  const FormaPagoVenta._();
  static const contado = 'CONTADO';
  static const credito = 'CREDITO';
  static const todas = [contado, credito];
}

/// Un pago parcial dentro de una nota de venta: un metodo y cuanto se pago.
class PagoVenta {
  const PagoVenta({
    required this.id,
    required this.metodoPagoId,
    required this.metodoPago,
    required this.monto,
    required this.fecha,
    this.usuario,
    this.anulado = false,
  });

  final int id;
  final int metodoPagoId;
  final String metodoPago;
  final double monto;
  final DateTime fecha;
  final String? usuario;
  final bool anulado;

  factory PagoVenta.desdeJson(Map<String, dynamic> json) => PagoVenta(
    id: json['id'] as int,
    metodoPagoId: json['metodoPagoId'] as int,
    metodoPago: json['metodoPago'] as String? ?? '',
    monto: (json['monto'] as num?)?.toDouble() ?? 0,
    fecha: DateTime.parse(json['fecha'] as String),
    usuario: json['usuario'] as String?,
    anulado: json['anulado'] as bool? ?? false,
  );
}

/// Una venta lista tal cual: nacio de confirmar un pedido o se registro
/// directa. El stock ya salio al momento de crearla — no hay estados de
/// "recibido parcial" como en una compra.
class NotaVenta {
  const NotaVenta({
    required this.id,
    required this.numero,
    required this.clienteId,
    required this.cliente,
    this.pedidoId,
    this.pedidoNumero,
    required this.almacenId,
    required this.almacen,
    required this.fecha,
    required this.estado,
    required this.formaPago,
    this.observacion,
    this.usuario,
    required this.total,
    required this.detalle,
    required this.pagos,
    required this.totalPagado,
  });

  final int id;
  final String numero;
  final int clienteId;
  final String cliente;

  /// Si nacio de confirmar un pedido, cual. Null si fue directa.
  final int? pedidoId;
  final String? pedidoNumero;

  final int almacenId;
  final String almacen;

  final DateTime fecha;

  /// CONFIRMADA o ANULADA.
  final String estado;

  /// CONTADO o CREDITO.
  final String formaPago;

  final String? observacion;
  final String? usuario;
  final double total;
  final List<LineaVenta> detalle;

  /// Con que se pago. Puede ser mas de un metodo — un pago mixto.
  final List<PagoVenta> pagos;

  /// Suma de pagos. Si es menor que total, falta esa diferencia por cobrar.
  final double totalPagado;

  String get buscable => '$numero $cliente'.toLowerCase();

  factory NotaVenta.desdeJson(Map<String, dynamic> json) => NotaVenta(
    id: json['id'] as int,
    numero: json['numero'] as String? ?? '',
    clienteId: json['clienteId'] as int,
    cliente: json['cliente'] as String? ?? '',
    pedidoId: json['pedidoId'] as int?,
    pedidoNumero: json['pedidoNumero'] as String?,
    almacenId: json['almacenId'] as int? ?? 0,
    almacen: json['almacen'] as String? ?? '',
    fecha: DateTime.parse(json['fecha'] as String),
    estado: json['estado'] as String? ?? EstadoNotaVenta.confirmada,
    formaPago: json['formaPago'] as String? ?? FormaPagoVenta.contado,
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    detalle: (json['detalle'] as List? ?? const [])
        .map((e) => LineaVenta.desdeJson(e as Map<String, dynamic>))
        .toList(),
    pagos: (json['pagos'] as List? ?? const [])
        .map((e) => PagoVenta.desdeJson(e as Map<String, dynamic>))
        .toList(),
    totalPagado: (json['totalPagado'] as num?)?.toDouble() ?? 0,
  );
}
