import '../../../compartido/fechas.dart';

/// La caja de quien esta logueado: su propio dinero en la ruta.
class MiCaja {
  const MiCaja({
    required this.id,
    required this.nombre,
    required this.saldoActual,
  });

  final int id;
  final String nombre;

  /// Lo que deberia tener ahora en la mano.
  final double saldoActual;

  factory MiCaja.desdeJson(Map<String, dynamic> json) => MiCaja(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    saldoActual: (json['saldoActual'] as num? ?? 0).toDouble(),
  );
}

/// De donde viene cada movimiento, dicho como se entiende en la ruta.
class DocumentoMovimiento {
  const DocumentoMovimiento._();

  static const etiquetas = <String, String>{
    'PAGO_VENTA': 'Cobro de venta',
    'MOVIMIENTO_OPERATIVO': 'Ingreso o egreso',
    'CIERRE_CAJA': 'Cierre de caja',
    'FALTANTE_CAJA': 'Faltante de cierre',
    'SOBRANTE_CAJA': 'Sobrante de cierre',
    'REVERSION': 'Anulación',
    'SALDO_INICIAL': 'Saldo inicial',
    'TRANSFERENCIA_INTERNA': 'Transferencia',
    'FINANCIAMIENTO': 'Préstamo recibido',
    'PAGO_FINANCIAMIENTO': 'Pago de préstamo',
    'RECUPERO_FALTANTE': 'Recupero de faltante',
  };

  static String etiqueta(String documento) => etiquetas[documento] ?? documento;
}

/// Un movimiento de la caja: lo que entro o salio y con que saldo quedo.
class MovimientoCaja {
  const MovimientoCaja({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.saldoResultante,
    required this.fecha,
    required this.documentoOrigen,
    this.observacion,
  });

  final int id;

  /// INGRESO o EGRESO.
  final String tipo;
  final double monto;
  final double saldoResultante;
  final DateTime fecha;

  /// De donde viene: PAGO_VENTA, CIERRE_CAJA... ver [DocumentoMovimiento].
  final String documentoOrigen;

  final String? observacion;

  bool get esIngreso => tipo == 'INGRESO';

  String get concepto => DocumentoMovimiento.etiqueta(documentoOrigen);

  String get buscable => '$concepto ${observacion ?? ''}'.toLowerCase();

  factory MovimientoCaja.desdeJson(Map<String, dynamic> json) => MovimientoCaja(
    id: json['id'] as int,
    tipo: json['tipo'] as String? ?? '',
    monto: (json['monto'] as num? ?? 0).toDouble(),
    saldoResultante: (json['saldoResultante'] as num? ?? 0).toDouble(),
    fecha: fechaDeJson(json['fecha'] as String),
    documentoOrigen: json['documentoOrigen'] as String? ?? '',
    observacion: json['observacion'] as String?,
  );
}

/// Una categoria para un ingreso o egreso libre.
class CategoriaMovimiento {
  const CategoriaMovimiento({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.origen,
  });

  final int id;
  final String nombre;

  /// INGRESO o EGRESO.
  final String tipo;

  /// OPERATIVO o NO_OPERATIVO.
  final String origen;

  String get etiqueta =>
      '$nombre · ${origen == 'OPERATIVO' ? 'Operativo' : 'No operativo'}';

  factory CategoriaMovimiento.desdeJson(Map<String, dynamic> json) =>
      CategoriaMovimiento(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        tipo: json['tipo'] as String? ?? '',
        origen: json['origen'] as String? ?? '',
      );
}

/// A quien se le puede entregar lo contado al cerrar: una caja o un banco.
class CuentaDestino {
  const CuentaDestino({
    required this.id,
    required this.nombre,
    required this.naturaleza,
  });

  final int id;
  final String nombre;
  final String naturaleza;

  String get etiqueta => switch (naturaleza) {
    'CAJA' => '$nombre · Caja',
    'BANCO' => '$nombre · Banco',
    'PASARELA' => '$nombre · Pasarela',
    _ => nombre,
  };

  factory CuentaDestino.desdeJson(Map<String, dynamic> json) => CuentaDestino(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    naturaleza: json['naturaleza'] as String? ?? '',
  );
}

/// Lo que dejo un cierre: cuanto se conto contra lo que habia que tener.
class CierreCaja {
  const CierreCaja({
    required this.saldoSistema,
    required this.contado,
    required this.diferencia,
    required this.cuentaDestino,
    required this.sinEmpleado,
  });

  final double saldoSistema;
  final double contado;

  /// Negativa: falto plata. Positiva: sobro.
  final double diferencia;

  final String cuentaDestino;

  /// El usuario no tiene empleado vinculado: su faltante no puede entrar en
  /// ninguna planilla hasta que se lo vincule.
  final bool sinEmpleado;

  factory CierreCaja.desdeJson(Map<String, dynamic> json) => CierreCaja(
    saldoSistema: (json['saldoSistema'] as num? ?? 0).toDouble(),
    contado: (json['contado'] as num? ?? 0).toDouble(),
    diferencia: (json['diferencia'] as num? ?? 0).toDouble(),
    cuentaDestino: json['cuentaDestino'] as String? ?? '',
    sinEmpleado: json['sinEmpleado'] as bool? ?? false,
  );
}
