/// Un pago de una nota de venta, aplanado con datos del cliente y la nota
/// a la que pertenece. Usado en el reporte "Mis cobros".
class Cobro {
  const Cobro({
    required this.id,
    required this.fecha,
    required this.notaVentaId,
    required this.notaVentaNumero,
    required this.clienteId,
    required this.cliente,
    required this.metodoPagoId,
    required this.metodoPago,
    required this.monto,
    required this.anulado,
  });

  final int id;
  final DateTime fecha;
  final int notaVentaId;
  final String notaVentaNumero;
  final int clienteId;
  final String cliente;
  final int metodoPagoId;
  final String metodoPago;
  final double monto;
  final bool anulado;

  String get buscable => '$notaVentaNumero $cliente'.toLowerCase();

  factory Cobro.desdeJson(Map<String, dynamic> json) => Cobro(
    id: json['id'] as int,
    fecha: DateTime.parse(json['fecha'] as String),
    notaVentaId: json['notaVentaId'] as int,
    notaVentaNumero: json['notaVentaNumero'] as String? ?? '',
    clienteId: json['clienteId'] as int,
    cliente: json['cliente'] as String? ?? '',
    metodoPagoId: json['metodoPagoId'] as int,
    metodoPago: json['metodoPago'] as String? ?? '',
    monto: (json['monto'] as num?)?.toDouble() ?? 0,
    anulado: json['anulado'] as bool? ?? false,
  );
}
