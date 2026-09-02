/// Modelos del modulo de configuracion: usuarios, roles y empresas.
///
/// Son un espejo de los `Response` del backend. Solo se leen campos: la app no
/// inventa datos derivados, para que un cambio en el API se note enseguida.
library;

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
  final int rolId;

  /// Nombre del rol: el backend lo manda resuelto para no pedirlo aparte.
  final String rol;

  final bool activo;

  String get buscable => '$nombre $email ${dni ?? ''} $rol'.toLowerCase();

  factory Usuario.desdeJson(Map<String, dynamic> json) => Usuario(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    email: json['email'] as String? ?? '',
    dni: json['dni'] as String?,
    rolId: json['rolId'] as int? ?? 0,
    rol: json['rol'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
  );
}

class Rol {
  const Rol({
    required this.id,
    required this.nombre,
    required this.activo,
    required this.delSistema,
    required this.protegido,
    required this.usuarios,
    this.descripcion,
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;

  /// Rol que trae el sistema de fabrica.
  final bool delSistema;

  /// No se puede desactivar ni eliminar: sin Administrador activo nadie podria
  /// volver a configurar el sistema.
  final bool protegido;

  /// Cuantos usuarios lo tienen asignado.
  final int usuarios;

  String get buscable => '$nombre ${descripcion ?? ''}'.toLowerCase();

  factory Rol.desdeJson(Map<String, dynamic> json) => Rol(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String?,
    activo: json['activo'] as bool? ?? true,
    delSistema: json['delSistema'] as bool? ?? false,
    protegido: json['protegido'] as bool? ?? false,
    usuarios: json['usuarios'] as int? ?? 0,
  );
}

class Empresa {
  const Empresa({
    required this.id,
    required this.razonSocial,
    required this.nombreComercial,
    required this.ruc,
    required this.activa,
    required this.habilitada,
    this.direccion,
    this.departamento,
    this.provincia,
    this.distrito,
    this.telefono,
    this.email,
    this.sitioWeb,
    this.representanteLegal,
  });

  final int id;
  final String razonSocial;
  final String nombreComercial;
  final String ruc;
  final String? direccion;
  final String? departamento;
  final String? provincia;
  final String? distrito;
  final String? telefono;
  final String? email;
  final String? sitioWeb;
  final String? representanteLegal;

  /// La empresa con la que opera el sistema. Solo puede haber una.
  final bool activa;

  /// Una empresa retirada sigue guardada pero no se puede activar.
  final bool habilitada;

  String get buscable => '$razonSocial $nombreComercial $ruc'.toLowerCase();

  factory Empresa.desdeJson(Map<String, dynamic> json) => Empresa(
    id: json['id'] as int,
    razonSocial: json['razonSocial'] as String? ?? '',
    nombreComercial: json['nombreComercial'] as String? ?? '',
    ruc: json['ruc'] as String? ?? '',
    direccion: json['direccion'] as String?,
    departamento: json['departamento'] as String?,
    provincia: json['provincia'] as String?,
    distrito: json['distrito'] as String?,
    telefono: json['telefono'] as String?,
    email: json['email'] as String?,
    sitioWeb: json['sitioWeb'] as String?,
    representanteLegal: json['representanteLegal'] as String?,
    activa: json['activa'] as bool? ?? false,
    habilitada: json['habilitada'] as bool? ?? true,
  );
}

/// Datos de SUNAT para llenar el formulario de empresa.
class ConsultaRuc {
  const ConsultaRuc({
    required this.ruc,
    required this.razonSocial,
    this.nombreComercial,
    this.direccion,
    this.departamento,
    this.provincia,
    this.distrito,
    this.estado,
    this.condicion,
  });

  final String ruc;
  final String razonSocial;
  final String? nombreComercial;
  final String? direccion;
  final String? departamento;
  final String? provincia;
  final String? distrito;

  /// ACTIVO / BAJA DE OFICIO / etc.
  final String? estado;

  /// HABIDO / NO HABIDO.
  final String? condicion;

  factory ConsultaRuc.desdeJson(Map<String, dynamic> json) => ConsultaRuc(
    ruc: json['ruc'] as String? ?? '',
    razonSocial: json['razonSocial'] as String? ?? '',
    nombreComercial: json['nombreComercial'] as String?,
    direccion: json['direccion'] as String?,
    departamento: json['departamento'] as String?,
    provincia: json['provincia'] as String?,
    distrito: json['distrito'] as String?,
    estado: json['estado'] as String?,
    condicion: json['condicion'] as String?,
  );
}
