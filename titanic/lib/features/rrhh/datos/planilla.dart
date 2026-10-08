import '../../../compartido/fechas.dart';

/// Estados de una planilla, igual que el backend.
class EstadoPlanilla {
  const EstadoPlanilla._();

  /// Armada pero sin pagar: se puede recalcular y ajustar.
  static const borrador = 'BORRADOR';
  static const pagada = 'PAGADA';
  static const anulada = 'ANULADA';

  static String etiqueta(String estado) => switch (estado) {
    borrador => 'Borrador',
    pagada => 'Pagada',
    anulada => 'Anulada',
    _ => estado,
  };
}

double _monto(Object? v) => (v as num? ?? 0).toDouble();

/// La planilla de una semana, de lunes a domingo, con una fila por empleado.
class Planilla {
  const Planilla({
    required this.id,
    required this.desde,
    required this.hasta,
    required this.estado,
    required this.totalCostoLaboral,
    required this.totalFaltantes,
    required this.totalNeto,
    this.totalAdelantos = 0,
    required this.detalle,
    this.cuentaFinanciera,
    this.fechaPago,
    this.fechasSinMarcar = const [],
  });

  final int id;
  final DateTime desde;
  final DateTime hasta;
  final String estado;

  /// De que cuenta salio la plata, si ya se pago.
  final String? cuentaFinanciera;
  final DateTime? fechaPago;

  /// El gasto de planilla: sueldos con sus ajustes, antes de los faltantes.
  final double totalCostoLaboral;
  final double totalFaltantes;

  /// Lo que se descuenta de adelantos esta semana, de todos.
  final double totalAdelantos;

  /// Lo que sale de la cuenta al pagar.
  final double totalNeto;

  final List<PlanillaDetalle> detalle;

  /// En borrador: los dias (lunes a sabado) en que a alguien le falta su marca. Se pagarian
  /// como trabajados, asi que hay que pasar lista antes de pagar.
  final List<DateTime> fechasSinMarcar;

  bool get esBorrador => estado == EstadoPlanilla.borrador;

  factory Planilla.desdeJson(Map<String, dynamic> json) => Planilla(
    id: json['id'] as int,
    desde: fechaDeJson(json['desde'] as String),
    hasta: fechaDeJson(json['hasta'] as String),
    estado: json['estado'] as String? ?? EstadoPlanilla.borrador,
    cuentaFinanciera: json['cuentaFinanciera'] as String?,
    fechaPago: fechaDeJsonOpcional(json['fechaPago']),
    totalCostoLaboral: _monto(json['totalCostoLaboral']),
    totalFaltantes: _monto(json['totalFaltantes']),
    totalAdelantos: _monto(json['totalAdelantos']),
    totalNeto: _monto(json['totalNeto']),
    detalle: [
      for (final d in json['detalle'] as List? ?? const [])
        PlanillaDetalle.desdeJson(d as Map<String, dynamic>),
    ],
    fechasSinMarcar: [
      for (final f in json['fechasSinMarcar'] as List? ?? const [])
        fechaDeJson(f as String),
    ],
  );
}

/// Lo que le toca a un empleado en la semana.
class PlanillaDetalle {
  const PlanillaDetalle({
    required this.id,
    required this.empleadoId,
    required this.empleado,
    required this.sueldoSemanal,
    required this.diasNoPagados,
    required this.descuentoInasistencias,
    this.diasSinMarcar = 0,
    this.descuentoAdelantos = 0,
    this.adelantosSugerido = 0,
    this.adelantosManual,
    this.adelantosSaldo = 0,
    required this.extraFeriados,
    required this.bonos,
    required this.otrosDescuentos,
    required this.descuentoFaltantes,
    required this.costoLaboral,
    required this.neto,
    this.cargo,
    this.notaAjuste,
  });

  final int id;
  final int empleadoId;
  final String empleado;
  final String? cargo;
  final double sueldoSemanal;

  /// Faltas y permisos de lunes a sabado: cada uno resta un dia de sueldo.
  final int diasNoPagados;
  final double descuentoInasistencias;

  /// Dias que se le pagan sin tener marca de asistencia.
  final int diasSinMarcar;

  /// Lo que se suma por trabajar un feriado.
  final double extraFeriados;

  final double bonos;
  final double otrosDescuentos;
  final String? notaAjuste;

  /// Los faltantes de caja que se le descuentan esta semana.
  final double descuentoFaltantes;

  /// Lo que se le descuenta esta semana de sus adelantos.
  final double descuentoAdelantos;

  /// Lo que le toca segun como se pactaron sus adelantos.
  final double adelantosSugerido;

  /// Lo que se decidio a mano para esta semana; null si va lo sugerido.
  final double? adelantosManual;

  /// Todo lo que debe de adelantos.
  final double adelantosSaldo;

  final double costoLaboral;

  /// Lo que se le paga.
  final double neto;

  String get buscable => '$empleado ${cargo ?? ''}'.toLowerCase();

  factory PlanillaDetalle.desdeJson(Map<String, dynamic> json) =>
      PlanillaDetalle(
        id: json['id'] as int,
        empleadoId: json['empleadoId'] as int,
        empleado: json['empleado'] as String? ?? '',
        cargo: json['cargo'] as String?,
        sueldoSemanal: _monto(json['sueldoSemanal']),
        diasNoPagados: json['diasNoPagados'] as int? ?? 0,
        diasSinMarcar: json['diasSinMarcar'] as int? ?? 0,
        descuentoInasistencias: _monto(json['descuentoInasistencias']),
        extraFeriados: _monto(json['extraFeriados']),
        bonos: _monto(json['bonos']),
        otrosDescuentos: _monto(json['otrosDescuentos']),
        notaAjuste: json['notaAjuste'] as String?,
        descuentoFaltantes: _monto(json['descuentoFaltantes']),
        descuentoAdelantos: _monto(json['descuentoAdelantos']),
        adelantosSugerido: _monto(json['adelantosSugerido']),
        adelantosManual: (json['adelantosManual'] as num?)?.toDouble(),
        adelantosSaldo: _monto(json['adelantosSaldo']),
        costoLaboral: _monto(json['costoLaboral']),
        neto: _monto(json['neto']),
      );
}

/// Una semana del historial, sin el detalle.
class PlanillaResumen {
  const PlanillaResumen({
    required this.id,
    required this.desde,
    required this.hasta,
    required this.estado,
    required this.empleados,
    required this.totalNeto,
    this.fechaPago,
  });

  final int id;
  final DateTime desde;
  final DateTime hasta;
  final String estado;
  final int empleados;
  final double totalNeto;
  final DateTime? fechaPago;

  factory PlanillaResumen.desdeJson(Map<String, dynamic> json) =>
      PlanillaResumen(
        id: json['id'] as int,
        desde: fechaDeJson(json['desde'] as String),
        hasta: fechaDeJson(json['hasta'] as String),
        estado: json['estado'] as String? ?? '',
        empleados: json['empleados'] as int? ?? 0,
        totalNeto: _monto(json['totalNeto']),
        fechaPago: fechaDeJsonOpcional(json['fechaPago']),
      );
}

/// Una cuenta de la que puede salir el pago: una caja o un banco.
class CuentaPago {
  const CuentaPago({
    required this.id,
    required this.nombre,
    required this.naturaleza,
    this.esBoveda = false,
  });

  final int id;
  final String nombre;
  final String naturaleza;

  /// La Boveda: el efectivo de la empresa. No es una caja.
  final bool esBoveda;

  String get etiqueta => switch (naturaleza) {
    _ when esBoveda => nombre == 'Bóveda' ? nombre : '$nombre · Bóveda',
    'CAJA' => '$nombre · Caja',
    'BANCO' => '$nombre · Banco',
    'PASARELA' => '$nombre · Pasarela',
    _ => nombre,
  };

  factory CuentaPago.desdeJson(Map<String, dynamic> json) => CuentaPago(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    naturaleza: json['naturaleza'] as String? ?? '',
    esBoveda: json['esBoveda'] as bool? ?? false,
  );
}
