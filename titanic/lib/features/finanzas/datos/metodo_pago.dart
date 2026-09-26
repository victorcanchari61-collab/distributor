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
/// transferencia. Lo comparten Compras, Cuentas por cobrar y Cuentas por
/// pagar.
///
/// Los datos del banco (numero de cuenta, CCI, titular) ya no viven aqui sino
/// en la cuenta financiera a la que apunta: un metodo solo dice a que cuenta
/// va la plata y, en una billetera, con que numero de celular se cobra.
class MetodoPago {
  const MetodoPago({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.activo,
    required this.usos,
    this.numero,
    this.cuentaFinancieraId,
    this.cuentaFinanciera,
  });

  final int id;
  final String nombre;
  final String tipo;

  /// El numero de celular, solo en billetera digital (Yape, Plin).
  final String? numero;

  /// A que cuenta va la plata. Null solo en Efectivo, que entra a la caja de
  /// quien cobra.
  final int? cuentaFinancieraId;

  /// Nombre de esa cuenta, solo para mostrar.
  final String? cuentaFinanciera;

  final bool activo;

  /// Cuantos documentos ya lo usan.
  final int usos;

  String get buscable =>
      '$nombre ${numero ?? ''} ${cuentaFinanciera ?? ''}'.toLowerCase();

  factory MetodoPago.desdeJson(Map<String, dynamic> json) => MetodoPago(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    tipo: json['tipo'] as String? ?? TipoMetodoPago.efectivo,
    numero: json['numero'] as String?,
    cuentaFinancieraId: json['cuentaFinancieraId'] as int?,
    cuentaFinanciera: json['cuentaFinanciera'] as String?,
    activo: json['activo'] as bool? ?? true,
    usos: json['usos'] as int? ?? 0,
  );

  /// Lo que acepta el backend al editar: el metodo tal cual, con su estado.
  Map<String, dynamic> aJson({required bool activo}) => {
    'nombre': nombre,
    'tipo': tipo,
    'numero': numero,
    'cuentaFinancieraId': cuentaFinancieraId,
    'activo': activo,
  };
}

/// Una cuenta financiera a la que puede apuntar un metodo de pago.
class CuentaFinancieraOpcion {
  const CuentaFinancieraOpcion({
    required this.id,
    required this.nombre,
    required this.naturaleza,
    required this.activo,
    this.banco,
  });

  final int id;
  final String nombre;

  /// CAJA, BANCO u otra. Las cajas no se eligen: esas son del Efectivo.
  final String naturaleza;

  final String? banco;
  final bool activo;

  /// Bancos y pasarelas activos, nunca una caja: el Efectivo no elige cuenta.
  bool get elegible => naturaleza != 'CAJA' && activo;

  /// "Cuenta corriente — BCP", como se lee en el desplegable.
  String get etiqueta =>
      banco == null || banco!.trim().isEmpty ? nombre : '$nombre — $banco';

  factory CuentaFinancieraOpcion.desdeJson(Map<String, dynamic> json) =>
      CuentaFinancieraOpcion(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        naturaleza: json['naturaleza'] as String? ?? '',
        banco: json['banco'] as String?,
        activo: json['activo'] as bool? ?? true,
      );
}

/// Lo justo para elegir con cuál se cobra: nombre y tipo, sin datos de cuenta
/// ni contadores.
///
/// Es lo que devuelve GET /api/metodopago/opciones, que solo trae los activos y
/// lo puede pedir quien convierte pedidos sin tener acceso al catálogo de
/// Finanzas. Por eso no reutiliza [MetodoPago]: aquí no hay `activo` ni `usos`
/// que inventar.
class MetodoPagoOpcion {
  const MetodoPagoOpcion({
    required this.id,
    required this.nombre,
    required this.tipo,
  });

  final int id;
  final String nombre;

  /// EFECTIVO, BILLETERA_DIGITAL o TRANSFERENCIA: ver [TipoMetodoPago].
  final String tipo;

  factory MetodoPagoOpcion.desdeJson(Map<String, dynamic> json) =>
      MetodoPagoOpcion(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        tipo: json['tipo'] as String? ?? TipoMetodoPago.efectivo,
      );
}
