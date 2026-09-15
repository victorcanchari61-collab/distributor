/// Hasta cuándo vale un permiso concedido a una persona suelta.
class Alcance {
  const Alcance._();

  /// Se gasta al usarlo. Es lo normal: se pide para un documento concreto.
  static const unaVez = 0;

  /// Vale hasta una fecha y hora.
  static const temporal = 1;

  /// No vence.
  static const permanente = 2;

  static const todos = [unaVez, temporal, permanente];

  static String etiqueta(int alcance) => switch (alcance) {
    unaVez => 'Una sola vez',
    temporal => 'Por un tiempo',
    permanente => 'Para siempre',
    _ => 'Desconocido',
  };

  /// Lo que implica elegirlo, dicho antes de conceder.
  static String explicacion(int alcance) => switch (alcance) {
    unaVez =>
      'Se gasta al usarlo. Es lo normal: se pide para un documento concreto.',
    temporal => 'Deja de valer solo, sin que nadie tenga que retirarlo.',
    permanente => 'No vence: queda hasta que alguien lo retire a mano.',
    _ => '',
  };
}

class EstadoSolicitud {
  const EstadoSolicitud._();

  static const pendiente = 0;
  static const aprobada = 1;
  static const rechazada = 2;

  static String etiqueta(int estado) => switch (estado) {
    pendiente => 'Pendiente',
    aprobada => 'Aprobada',
    rechazada => 'Rechazada',
    _ => 'Desconocido',
  };
}

/// Lo que alguien pidió al toparse con una acción bloqueada.
class SolicitudPermiso {
  const SolicitudPermiso({
    required this.id,
    required this.usuarioId,
    required this.usuario,
    required this.submodulo,
    required this.accion,
    this.motivo,
    this.referencia,
    required this.estado,
    required this.fechaSolicitud,
    this.fechaResolucion,
    this.respuesta,
  });

  final int id;
  final int usuarioId;

  /// Nombre de quien pide, ya resuelto por el backend.
  final String usuario;

  final String submodulo;
  final String accion;

  /// Para qué lo necesita. Lo escribe quien pide, no quien aprueba.
  final String? motivo;

  /// El documento sobre el que iba, si venía de uno.
  final String? referencia;

  final int estado;
  final DateTime fechaSolicitud;
  final DateTime? fechaResolucion;
  final String? respuesta;

  bool get pendiente => estado == EstadoSolicitud.pendiente;

  factory SolicitudPermiso.desdeJson(Map<String, dynamic> json) =>
      SolicitudPermiso(
        id: json['id'] as int,
        usuarioId: json['usuarioId'] as int? ?? 0,
        usuario: json['usuario'] as String? ?? '',
        submodulo: json['submodulo'] as String? ?? '',
        accion: json['accion'] as String? ?? '',
        motivo: json['motivo'] as String?,
        referencia: json['referencia'] as String?,
        estado: json['estado'] as int? ?? EstadoSolicitud.pendiente,
        fechaSolicitud:
            DateTime.tryParse(json['fechaSolicitud'] as String? ?? '') ??
            DateTime.now(),
        fechaResolucion: DateTime.tryParse(
          json['fechaResolucion'] as String? ?? '',
        ),
        respuesta: json['respuesta'] as String?,
      );
}

/// Un permiso que tiene una persona y su rol no le da.
class UsuarioPermiso {
  const UsuarioPermiso({
    required this.id,
    required this.usuarioId,
    required this.submodulo,
    required this.accion,
    required this.alcance,
    this.expiraEn,
    required this.usos,
    required this.revocado,
    this.motivo,
    required this.fechaOtorgado,
    required this.vigente,
  });

  final int id;
  final int usuarioId;
  final String submodulo;
  final String accion;
  final int alcance;
  final DateTime? expiraEn;

  /// Veces que se usó. Solo cuenta para los de una sola vez.
  final int usos;

  final bool revocado;
  final String? motivo;
  final DateTime fechaOtorgado;

  /// Si ahora mismo sirve. Lo calcula el servidor: aquí no se vuelve a decidir
  /// para que no haya dos respuestas distintas a la misma pregunta.
  final bool vigente;

  factory UsuarioPermiso.desdeJson(Map<String, dynamic> json) => UsuarioPermiso(
    id: json['id'] as int,
    usuarioId: json['usuarioId'] as int? ?? 0,
    submodulo: json['submodulo'] as String? ?? '',
    accion: json['accion'] as String? ?? '',
    alcance: json['alcance'] as int? ?? Alcance.unaVez,
    expiraEn: DateTime.tryParse(json['expiraEn'] as String? ?? ''),
    usos: json['usos'] as int? ?? 0,
    revocado: json['revocado'] as bool? ?? false,
    motivo: json['motivo'] as String?,
    fechaOtorgado:
        DateTime.tryParse(json['fechaOtorgado'] as String? ?? '') ??
        DateTime.now(),
    vigente: json['vigente'] as bool? ?? false,
  );
}
