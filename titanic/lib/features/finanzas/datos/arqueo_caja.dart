/// Cierre de caja de un dia: lo que se esperaba tener en efectivo contra lo
/// contado a mano.
class ArqueoCaja {
  const ArqueoCaja({
    required this.id,
    required this.fecha,
    required this.montoEsperado,
    required this.montoContado,
    required this.diferencia,
    this.observacion,
    this.usuario,
    required this.fechaCreacion,
  });

  final int id;
  final DateTime fecha;
  final double montoEsperado;
  final double montoContado;

  /// montoContado - montoEsperado. Negativo es faltante, positivo es sobrante.
  final double diferencia;
  final String? observacion;
  final String? usuario;
  final DateTime fechaCreacion;

  factory ArqueoCaja.desdeJson(Map<String, dynamic> json) => ArqueoCaja(
    id: json['id'] as int,
    fecha: DateTime.parse(json['fecha'] as String),
    montoEsperado: (json['montoEsperado'] as num?)?.toDouble() ?? 0,
    montoContado: (json['montoContado'] as num?)?.toDouble() ?? 0,
    diferencia: (json['diferencia'] as num?)?.toDouble() ?? 0,
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    fechaCreacion: DateTime.parse(json['fechaCreacion'] as String),
  );
}

/// Resumen del dia: cuanto se cobro y pago en efectivo, y el arqueo ya
/// registrado para esa fecha, si existe.
class ArqueoResumen {
  const ArqueoResumen({
    required this.fecha,
    required this.cobradoEfectivo,
    required this.pagadoEfectivo,
    required this.montoEsperado,
    this.arqueo,
  });

  final DateTime fecha;
  final double cobradoEfectivo;
  final double pagadoEfectivo;
  final double montoEsperado;
  final ArqueoCaja? arqueo;

  factory ArqueoResumen.desdeJson(Map<String, dynamic> json) => ArqueoResumen(
    fecha: DateTime.parse(json['fecha'] as String),
    cobradoEfectivo: (json['cobradoEfectivo'] as num?)?.toDouble() ?? 0,
    pagadoEfectivo: (json['pagadoEfectivo'] as num?)?.toDouble() ?? 0,
    montoEsperado: (json['montoEsperado'] as num?)?.toDouble() ?? 0,
    arqueo: json['arqueo'] == null
        ? null
        : ArqueoCaja.desdeJson(json['arqueo'] as Map<String, dynamic>),
  );
}
