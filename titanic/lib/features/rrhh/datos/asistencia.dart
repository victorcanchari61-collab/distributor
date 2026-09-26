import '../../../compartido/fechas.dart';

/// Los estados de una marca, igual que el backend.
class EstadoAsistencia {
  const EstadoAsistencia._();

  static const presente = 'PRESENTE';
  static const tardanza = 'TARDANZA';
  static const falta = 'FALTA';
  static const permiso = 'PERMISO';

  static const todos = [presente, tardanza, falta, permiso];

  static String etiqueta(String estado) => switch (estado) {
    presente => 'Presente',
    tardanza => 'Tardanza',
    falta => 'Falta',
    permiso => 'Permiso',
    _ => estado,
  };
}

/// Un empleado, un dia: si vino, falto, llego tarde o tuvo permiso.
class Asistencia {
  const Asistencia({
    required this.id,
    required this.empleadoId,
    required this.empleado,
    required this.fecha,
    required this.estado,
    required this.anulado,
    this.cargo,
    this.observacion,
    this.usuario,
  });

  final int id;
  final int empleadoId;
  final String empleado;
  final String? cargo;

  /// Solo el dia: la hora no importa.
  final DateTime fecha;

  final String estado;
  final String? observacion;

  /// Quien la registro.
  final String? usuario;

  /// Anulada por error: no cuenta, pero queda en el historial.
  final bool anulado;

  String get buscable =>
      '$empleado ${cargo ?? ''} ${observacion ?? ''}'.toLowerCase();

  factory Asistencia.desdeJson(Map<String, dynamic> json) => Asistencia(
    id: json['id'] as int,
    empleadoId: json['empleadoId'] as int,
    empleado: json['empleado'] as String? ?? '',
    cargo: json['cargo'] as String?,
    fecha: fechaDeJson(json['fecha'] as String),
    estado: json['estado'] as String? ?? '',
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    anulado: json['anulado'] as bool? ?? false,
  );
}

/// Cuantos hay de cada estado en el rango consultado.
class ResumenAsistencia {
  const ResumenAsistencia({
    required this.presentes,
    required this.tardanzas,
    required this.faltas,
    required this.permisos,
  });

  final int presentes;
  final int tardanzas;
  final int faltas;
  final int permisos;

  factory ResumenAsistencia.desdeJson(Map<String, dynamic> json) =>
      ResumenAsistencia(
        presentes: json['presentes'] as int? ?? 0,
        tardanzas: json['tardanzas'] as int? ?? 0,
        faltas: json['faltas'] as int? ?? 0,
        permisos: json['permisos'] as int? ?? 0,
      );
}

/// Un dia no laborable. Quien lo trabaja cobra ese dia doble en la planilla.
class Feriado {
  const Feriado({required this.id, required this.fecha, required this.nombre});

  final int id;
  final DateTime fecha;
  final String nombre;

  factory Feriado.desdeJson(Map<String, dynamic> json) => Feriado(
    id: json['id'] as int,
    fecha: fechaDeJson(json['fecha'] as String),
    nombre: json['nombre'] as String? ?? '',
  );
}
