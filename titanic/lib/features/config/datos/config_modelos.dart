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
    this.rolIds = const [],
    required this.rol,
    required this.activo,
    this.dni,
    this.nombreUsuario,
    this.empleadoId,
    this.empleado,
    this.rutaIds = const [],
    this.rutas = const [],
  });

  final int id;
  final String nombre;
  final String email;
  final String? dni;

  /// El usuario que eligió para iniciar sesión; opcional. Sirve igual que el correo o el DNI.
  final String? nombreUsuario;

  /// El rol principal.
  final int rolId;

  /// Todos sus roles, el principal primero. Una persona puede tener varios; sus permisos son la unión.
  final List<int> rolIds;

  /// Nombre del rol: el backend lo manda resuelto para no pedirlo aparte.
  final String rol;

  /// Su ficha en Empleados, si la cuenta pertenece a alguien del padron. Es
  /// opcional: la de soporte y la del dueño no son de nadie del padron.
  final int? empleadoId;

  /// Nombre de ese empleado, solo para mostrar.
  final String? empleado;

  /// Las rutas que tiene a cargo: su cartera de clientes. Pueden ser varias. Son de la PERSONA, no
  /// del rol: el dueño también vende y tiene la suya. Solas no restringen nada; lo hace el alcance
  /// del rol, y con él ve los clientes de todas sus rutas.
  final List<int> rutaIds;
  final List<String> rutas;

  final bool activo;

  String get buscable =>
      '$nombre ${nombreUsuario ?? ''} $email ${dni ?? ''} $rol ${empleado ?? ''} ${rutas.join(' ')}'
          .toLowerCase();

  factory Usuario.desdeJson(Map<String, dynamic> json) => Usuario(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    email: json['email'] as String? ?? '',
    dni: json['dni'] as String?,
    nombreUsuario: json['nombreUsuario'] as String?,
    rolId: json['rolId'] as int? ?? 0,
    rolIds: [for (final r in (json['rolIds'] as List? ?? const [])) r as int],
    rol: json['rol'] as String? ?? '',
    empleadoId: json['empleadoId'] as int?,
    empleado: json['empleado'] as String?,
    rutaIds: [for (final r in (json['rutaIds'] as List? ?? const [])) r as int],
    rutas: [for (final r in (json['rutas'] as List? ?? const [])) r as String],
    activo: json['activo'] as bool? ?? true,
  );
}

/// Una accion concedida sobre un submodulo: "fact.pedidos" + "anular".
///
/// La existencia de la fila ES el permiso, por eso no hay banderas: antes un
/// permiso era un modulo con ver/crear/editar/eliminar y marcar "Inventario:
/// editar" concedia de golpe ajustes, transferencias y prestamos.
class RolPermiso {
  const RolPermiso({required this.submodulo, required this.accion});

  /// Clave del menu: 'fact.pedidos'.
  final String submodulo;

  /// ver, crear, editar, anular, eliminar, exportar, importar, confirmar, cobrar.
  final String accion;

  /// Como lo guarda el backend, y como se marca en la matriz de Accesos.
  String get clave => '$submodulo:$accion';

  Map<String, dynamic> aCuerpo() => {'submodulo': submodulo, 'accion': accion};

  factory RolPermiso.desdeJson(Map<String, dynamic> json) => RolPermiso(
    submodulo: json['submodulo'] as String? ?? '',
    accion: json['accion'] as String? ?? '',
  );
}

/// Un submodulo del sistema y las acciones que admite.
///
/// Viene de GET /api/permiso/catalogo y es lo que dibuja la matriz de Accesos.
/// La app no lleva su propia lista a proposito: si la copiara, un submodulo
/// nuevo quedaria invisible en la configuracion aunque el backend ya lo
/// estuviera exigiendo.
class SubmoduloCatalogo {
  const SubmoduloCatalogo({
    required this.submodulo,
    required this.modulo,
    required this.acciones,
  });

  /// Clave del menu: 'fact.pedidos'.
  final String submodulo;

  /// Modulo al que pertenece: el prefijo de la clave, ya resuelto por el backend.
  final String modulo;

  /// Solo las que tienen sentido aqui: la auditoria no se crea, el kardex no
  /// se anula.
  final List<String> acciones;

  factory SubmoduloCatalogo.desdeJson(Map<String, dynamic> json) =>
      SubmoduloCatalogo(
        submodulo: json['submodulo'] as String? ?? '',
        modulo: json['modulo'] as String? ?? '',
        acciones: [
          for (final a in json['acciones'] as List? ?? const []) a as String,
        ],
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
    required this.permisos,
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

  final List<RolPermiso> permisos;

  String get buscable => '$nombre ${descripcion ?? ''}'.toLowerCase();

  factory Rol.desdeJson(Map<String, dynamic> json) => Rol(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String?,
    activo: json['activo'] as bool? ?? true,
    delSistema: json['delSistema'] as bool? ?? false,
    protegido: json['protegido'] as bool? ?? false,
    usuarios: json['usuarios'] as int? ?? 0,
    permisos: (json['permisos'] as List? ?? const [])
        .map((e) => RolPermiso.desdeJson(e as Map<String, dynamic>))
        .toList(),
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
    this.ubigeo,
    this.usuarioSol,
    this.tieneClaveSol = false,
    this.modoPrueba = true,
    this.certificadoTitular,
    this.tieneCertificado = false,
    this.certificadoVenceEl,
    this.certificadoVencido = false,
    this.whatsAppAutomatico = false,
    this.whatsAppPlantilla,
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

  // --- Facturacion electronica ---

  /// Ubigeo de 6 digitos del domicilio fiscal: el comprobante electronico lo exige.
  final String? ubigeo;
  final String? usuarioSol;

  /// Hay una clave SOL guardada. La clave en si nunca llega al telefono.
  final bool tieneClaveSol;

  /// true: emite al entorno de pruebas de SUNAT (sin validez tributaria). false: produccion.
  final bool modoPrueba;

  final String? certificadoTitular;

  /// Hay un certificado guardado. El certificado en si nunca llega al telefono.
  final bool tieneCertificado;
  final DateTime? certificadoVenceEl;
  final bool certificadoVencido;

  // --- WhatsApp ---

  /// Cada comprobante aceptado por SUNAT se manda solo al telefono del cliente.
  final bool whatsAppAutomatico;

  /// El mensaje con sus {variables}; nulo: el mensaje de siempre.
  final String? whatsAppPlantilla;

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
    ubigeo: json['ubigeo'] as String?,
    usuarioSol: json['usuarioSol'] as String?,
    tieneClaveSol: json['tieneClaveSol'] as bool? ?? false,
    modoPrueba: json['modoPrueba'] as bool? ?? true,
    certificadoTitular: json['certificadoTitular'] as String?,
    tieneCertificado: json['tieneCertificado'] as bool? ?? false,
    certificadoVenceEl: json['certificadoVenceEl'] is String
        ? DateTime.tryParse(json['certificadoVenceEl'] as String)
        : null,
    certificadoVencido: json['certificadoVencido'] as bool? ?? false,
    whatsAppAutomatico: json['whatsAppAutomatico'] as bool? ?? false,
    whatsAppPlantilla: json['whatsAppPlantilla'] as String?,
  );
}

/// Una serie de comprobantes de la empresa y hasta que numero llego.
class SerieCpe {
  const SerieCpe({
    required this.id,
    required this.tipo,
    required this.serie,
    required this.ultimoNumero,
    required this.activa,
    this.aplicaA,
    this.emitidos = 0,
  });

  factory SerieCpe.desdeJson(Map<String, dynamic> j) => SerieCpe(
    id: j['id'] as int,
    tipo: j['tipo'] as String,
    serie: j['serie'] as String,
    aplicaA: j['aplicaA'] as String?,
    ultimoNumero: j['ultimoNumero'] as int? ?? 0,
    activa: j['activa'] as bool? ?? true,
    emitidos: j['emitidos'] as int? ?? 0,
  );

  final int id;

  /// 01 factura, 03 boleta, 07 nota de credito, 08 nota de debito.
  final String tipo;
  final String serie;

  /// Solo en notas: 01 si corrigen facturas, 03 si corrigen boletas.
  final String? aplicaA;

  /// El ultimo numero usado; el siguiente comprobante sale con este mas uno.
  final int ultimoNumero;
  final bool activa;

  /// Comprobantes emitidos con esta serie desde el sistema.
  final int emitidos;

  static String nombreTipo(String tipo) => switch (tipo) {
    '01' => 'Factura',
    '03' => 'Boleta',
    '07' => 'Nota de crédito',
    _ => 'Nota de débito',
  };
}

/// Como esta el servicio de WhatsApp de la empresa.
class EstadoWhatsApp {
  const EstadoWhatsApp({
    required this.estado,
    this.enCola = 0,
    this.qrImagen,
    this.error,
    this.faltaToken = false,
  });

  factory EstadoWhatsApp.desdeJson(Map<String, dynamic> j) => EstadoWhatsApp(
    estado: j['estado'] as String? ?? 'sin-servicio',
    enCola: j['enCola'] as int? ?? 0,
    qrImagen: j['qrImagen'] as String?,
    error: j['error'] as String?,
    faltaToken: j['faltaToken'] as bool? ?? false,
  );

  /// conectado, esperando-qr, desconectado o sin-servicio.
  final String estado;
  final int enCola;

  /// El QR a escanear, como imagen (data URL). Nulo si no hace falta.
  final String? qrImagen;
  final String? error;
  final bool faltaToken;
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
