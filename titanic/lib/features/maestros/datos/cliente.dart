/// Cliente: bodega o puesto al que se vende.
class Cliente {
  const Cliente({
    required this.id,
    required this.documento,
    required this.tipoDoc,
    required this.nombre,
    required this.activo,
    this.direccion,
    this.distritoId,
    this.distrito,
    this.provinciaId,
    this.provincia,
    this.departamentoId,
    this.departamento,
    this.telefono,
    this.email,
    this.diaVisita,
    this.rutaId,
    this.ruta,
    this.mercadoId,
    this.mercado,
  });

  final int id;
  final String documento;

  /// DNI, RUC o CODIGO.
  final String tipoDoc;

  final String nombre;
  final String? direccion;

  /// Distrito del ubigeo oficial (INEI/RENIEC), referencia al catalogo.
  final int? distritoId;

  /// Nombre del distrito, solo para mostrar: no se envia al guardar.
  final String? distrito;
  final int? provinciaId;
  final String? provincia;
  final int? departamentoId;
  final String? departamento;

  final String? telefono;
  final String? email;

  /// Dia en que el vendedor lo visita.
  final String? diaVisita;

  /// Ruta de reparto, referencia al catalogo.
  final int? rutaId;

  /// Nombre de la ruta, solo para mostrar: no se envia al guardar.
  final String? ruta;

  /// Mercado donde se entrega, referencia al catalogo.
  final int? mercadoId;

  /// Nombre del mercado, solo para mostrar: no se envia al guardar.
  final String? mercado;

  final bool activo;

  /// Texto contra el que se busca en la lista.
  String get buscable =>
      '$documento $nombre ${direccion ?? ''} ${distrito ?? ''} ${mercado ?? ''} ${ruta ?? ''}'
          .toLowerCase();

  factory Cliente.desdeJson(Map<String, dynamic> json) => Cliente(
    id: json['id'] as int,
    documento: json['documento'] as String? ?? '',
    tipoDoc: json['tipoDoc'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    direccion: json['direccion'] as String?,
    distritoId: json['distritoId'] as int?,
    distrito: json['distrito'] as String?,
    provinciaId: json['provinciaId'] as int?,
    provincia: json['provincia'] as String?,
    departamentoId: json['departamentoId'] as int?,
    departamento: json['departamento'] as String?,
    telefono: json['telefono'] as String?,
    email: json['email'] as String?,
    diaVisita: json['diaVisita'] as String?,
    rutaId: json['rutaId'] as int?,
    ruta: json['ruta'] as String?,
    mercadoId: json['mercadoId'] as int?,
    mercado: json['mercado'] as String?,
    activo: json['activo'] as bool? ?? true,
  );

  Map<String, dynamic> aJson() => {
    'documento': documento,
    'tipoDoc': tipoDoc,
    'nombre': nombre,
    'direccion': direccion,
    'distritoId': distritoId,
    'telefono': telefono,
    'email': email,
    'diaVisita': diaVisita,
    'rutaId': rutaId,
    'mercadoId': mercadoId,
  };

  Cliente copiar({
    String? documento,
    String? tipoDoc,
    String? nombre,
    String? direccion,
    int? distritoId,
    String? telefono,
    String? email,
    String? diaVisita,
    int? rutaId,
    int? mercadoId,
    bool? activo,
  }) => Cliente(
    id: id,
    documento: documento ?? this.documento,
    tipoDoc: tipoDoc ?? this.tipoDoc,
    nombre: nombre ?? this.nombre,
    direccion: direccion ?? this.direccion,
    distritoId: distritoId ?? this.distritoId,
    distrito: distrito,
    provinciaId: provinciaId,
    provincia: provincia,
    departamentoId: departamentoId,
    departamento: departamento,
    telefono: telefono ?? this.telefono,
    email: email ?? this.email,
    diaVisita: diaVisita ?? this.diaVisita,
    rutaId: rutaId ?? this.rutaId,
    ruta: ruta,
    mercadoId: mercadoId ?? this.mercadoId,
    mercado: mercado,
    activo: activo ?? this.activo,
  );
}
