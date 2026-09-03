/// Tipos de metodo de pago, igual que el backend.
class TipoMetodoPago {
  const TipoMetodoPago._();

  static const efectivo = 'EFECTIVO';
  static const billeteraDigital = 'BILLETERA_DIGITAL';
  static const transferencia = 'TRANSFERENCIA';

  static const todos = [efectivo, billeteraDigital, transferencia];

  static String etiqueta(String tipo) => switch (tipo) {
    efectivo => 'Efectivo',
    billeteraDigital => 'Billetera digital',
    transferencia => 'Transferencia',
    _ => tipo,
  };
}

/// Un metodo de pago del catalogo: efectivo, billetera digital o
/// transferencia. Lo comparten Compras, Cuentas por cobrar, Cuentas por
/// pagar, Mis cobros y el Arqueo diario.
class MetodoPago {
  const MetodoPago({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.activo,
    required this.usos,
    this.banco,
    this.numeroCuenta,
    this.cci,
    this.titular,
  });

  final int id;
  final String nombre;
  final String tipo;
  final String? banco;
  final String? numeroCuenta;
  final String? cci;
  final String? titular;
  final bool activo;

  /// Cuantos documentos ya lo usan.
  final int usos;

  String get buscable =>
      '$nombre ${banco ?? ''} ${numeroCuenta ?? ''} ${titular ?? ''}'.toLowerCase();

  factory MetodoPago.desdeJson(Map<String, dynamic> json) => MetodoPago(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    tipo: json['tipo'] as String? ?? TipoMetodoPago.efectivo,
    banco: json['banco'] as String?,
    numeroCuenta: json['numeroCuenta'] as String?,
    cci: json['cci'] as String?,
    titular: json['titular'] as String?,
    activo: json['activo'] as bool? ?? true,
    usos: json['usos'] as int? ?? 0,
  );
}
