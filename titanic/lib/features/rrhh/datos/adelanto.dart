import '../../../compartido/fechas.dart';

double _monto(Object? v) => (v as num? ?? 0).toDouble();

/// Los estados de un adelanto, igual que el backend.
class EstadoAdelanto {
  /// Todavia tiene saldo por descontar en planilla.
  static const pendiente = 'PENDIENTE';
  static const descontado = 'DESCONTADO';
  static const anulado = 'ANULADO';

  static const todos = [pendiente, descontado, anulado];

  static String etiqueta(String estado) => switch (estado) {
    pendiente => 'Por descontar',
    descontado => 'Descontado',
    anulado => 'Anulado',
    _ => estado,
  };
}

/// Plata que se le da a un trabajador a cuenta de su sueldo. Se le descuenta
/// en la planilla: todo de una vez o de a una cuota por semana, desde la
/// semana que se eligio.
class Adelanto {
  const Adelanto({
    required this.id,
    required this.empleadoId,
    required this.empleado,
    required this.fecha,
    required this.monto,
    required this.descontado,
    required this.saldo,
    required this.descontarDesde,
    required this.estado,
    this.cuotaSemanal,
    this.cuentaFinanciera,
    this.cargo,
    this.observacion,
    this.usuario,
    this.descuentos = const [],
  });

  final int id;
  final int empleadoId;
  final String empleado;
  final DateTime fecha;
  final double monto;
  final double descontado;
  final double saldo;

  /// El lunes de la primera semana en que se descuenta.
  final DateTime descontarDesde;

  /// Cuanto por semana; null es todo de una vez.
  final double? cuotaSemanal;
  final String estado;
  final String? cuentaFinanciera;

  // Solo en el detalle.
  final String? cargo;
  final String? observacion;
  final String? usuario;
  final List<AdelantoDescuento> descuentos;

  bool get pendiente => estado == EstadoAdelanto.pendiente;

  String get comoSeDescuenta => cuotaSemanal == null
      ? 'Todo de una vez'
      : 'S/ ${cuotaSemanal!.toStringAsFixed(2)} por semana';

  String get buscable => '$empleado ${cuentaFinanciera ?? ''}'.toLowerCase();

  factory Adelanto.desdeJson(Map<String, dynamic> json) => Adelanto(
    id: json['id'] as int,
    empleadoId: json['empleadoId'] as int,
    empleado: json['empleado'] as String? ?? '',
    fecha: fechaDeJson(json['fecha'] as String),
    monto: _monto(json['monto']),
    descontado: _monto(json['descontado']),
    saldo: _monto(json['saldo']),
    descontarDesde: fechaDeJson(json['descontarDesde'] as String),
    cuotaSemanal: (json['cuotaSemanal'] as num?)?.toDouble(),
    estado: json['estado'] as String? ?? EstadoAdelanto.pendiente,
    cuentaFinanciera: json['cuentaFinanciera'] as String?,
    cargo: json['cargo'] as String?,
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    descuentos: [
      for (final d in json['descuentos'] as List? ?? const [])
        AdelantoDescuento.desdeJson(d as Map<String, dynamic>),
    ],
  );
}

/// Lo descontado de un adelanto en una planilla pagada.
class AdelantoDescuento {
  const AdelantoDescuento({
    required this.planillaId,
    required this.desde,
    required this.hasta,
    required this.monto,
    this.fechaPago,
  });

  final int planillaId;
  final DateTime desde;
  final DateTime hasta;
  final double monto;
  final DateTime? fechaPago;

  factory AdelantoDescuento.desdeJson(Map<String, dynamic> json) =>
      AdelantoDescuento(
        planillaId: json['planillaId'] as int,
        desde: fechaDeJson(json['desde'] as String),
        hasta: fechaDeJson(json['hasta'] as String),
        monto: _monto(json['monto']),
        fechaPago: fechaDeJsonOpcional(json['fechaPago']),
      );
}

/// Las tarjetas de arriba.
class ResumenAdelantos {
  const ResumenAdelantos({
    this.saldoPendiente = 0,
    this.vigentes = 0,
    this.empleados = 0,
    this.entregadoMes = 0,
  });

  final double saldoPendiente;
  final int vigentes;
  final int empleados;
  final double entregadoMes;

  factory ResumenAdelantos.desdeJson(Map<String, dynamic> json) =>
      ResumenAdelantos(
        saldoPendiente: _monto(json['saldoPendiente']),
        vigentes: json['vigentes'] as int? ?? 0,
        empleados: json['empleados'] as int? ?? 0,
        entregadoMes: _monto(json['entregadoMes']),
      );
}

/// Un empleado para darle un adelanto: con su sueldo y lo que ya debe.
class EmpleadoAdelanto {
  const EmpleadoAdelanto({
    required this.id,
    required this.nombreCompleto,
    this.cargo,
    this.sueldoSemanal,
    this.saldoAdelantos = 0,
  });

  final int id;
  final String nombreCompleto;
  final String? cargo;
  final double? sueldoSemanal;
  final double saldoAdelantos;

  factory EmpleadoAdelanto.desdeJson(Map<String, dynamic> json) =>
      EmpleadoAdelanto(
        id: json['id'] as int,
        nombreCompleto: json['nombreCompleto'] as String? ?? '',
        cargo: json['cargo'] as String?,
        sueldoSemanal: (json['sueldoSemanal'] as num?)?.toDouble(),
        saldoAdelantos: _monto(json['saldoAdelantos']),
      );
}
