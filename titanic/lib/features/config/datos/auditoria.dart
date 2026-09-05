/// Un cambio registrado por el sistema: que entidad, que se le hizo, quien y
/// cuando. Lo escribe el backend al guardar; aqui solo se lee.
class RegistroAuditoria {
  const RegistroAuditoria({
    required this.id,
    required this.fecha,
    this.usuarioId,
    required this.usuario,
    required this.entidad,
    required this.entidadId,
    required this.accion,
    this.valoresAnteriores,
    this.valoresNuevos,
  });

  final int id;
  final DateTime fecha;
  final int? usuarioId;

  /// "Sistema" cuando el cambio no vino de una sesion.
  final String usuario;
  final String entidad;
  final String entidadId;

  /// CREADO, ACTUALIZADO o ELIMINADO.
  final String accion;

  /// Campo → valor. En una edicion solo los que cambiaron; en alta o baja, todo.
  final Map<String, dynamic>? valoresAnteriores;
  final Map<String, dynamic>? valoresNuevos;

  /// Todos los campos tocados, sin repetir, en el orden en que aparecen.
  List<String> get campos => {
    ...?valoresAnteriores?.keys,
    ...?valoresNuevos?.keys,
  }.toList();

  String get buscable => '$usuario $entidad $entidadId $accion'.toLowerCase();

  factory RegistroAuditoria.desdeJson(Map<String, dynamic> json) => RegistroAuditoria(
    id: json['id'] as int,
    fecha: DateTime.parse(json['fecha'] as String),
    usuarioId: json['usuarioId'] as int?,
    usuario: json['usuario'] as String? ?? 'Sistema',
    entidad: json['entidad'] as String? ?? '',
    entidadId: json['entidadId'] as String? ?? '',
    accion: json['accion'] as String? ?? '',
    valoresAnteriores: (json['valoresAnteriores'] as Map?)?.cast<String, dynamic>(),
    valoresNuevos: (json['valoresNuevos'] as Map?)?.cast<String, dynamic>(),
  );
}

class AccionAuditoria {
  const AccionAuditoria._();
  static const creado = 'CREADO';
  static const actualizado = 'ACTUALIZADO';
  static const eliminado = 'ELIMINADO';
}
