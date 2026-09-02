/// Usuario autenticado, tal como lo devuelve el backend.
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rolId,
    required this.rol,
    required this.activo,
    this.dni,
  });

  final int id;
  final String nombre;
  final String email;
  final String? dni;

  /// Id de la tabla Roles.
  final int rolId;

  /// Nombre del rol ya resuelto: "Administrador", "Vendedor", "Almacenero".
  final String rol;

  final bool activo;

  bool get esAdministrador => rol == 'Administrador';

  /// Primera letra del nombre, para el avatar.
  String get inicial =>
      nombre.isEmpty ? '?' : nombre.substring(0, 1).toUpperCase();

  factory Usuario.desdeJson(Map<String, dynamic> json) => Usuario(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    email: json['email'] as String? ?? '',
    dni: json['dni'] as String?,
    rolId: json['rolId'] as int? ?? 0,
    rol: json['rol'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
  );

  Map<String, dynamic> aJson() => {
    'id': id,
    'nombre': nombre,
    'email': email,
    'dni': dni,
    'rolId': rolId,
    'rol': rol,
    'activo': activo,
  };
}
