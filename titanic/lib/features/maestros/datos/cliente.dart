/// Cliente: bodega o puesto al que se vende.
class Cliente {
  const Cliente({
    required this.id,
    required this.documento,
    required this.tipoDoc,
    required this.nombre,
    required this.activo,
    this.documentoAlterno,
    this.tipoDocAlterno,
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
    this.vendedorId,
    this.vendedor,
    this.categoriaCodigo,
    this.categoriaNombre,
    this.categoriaColor,
    this.deudaPendiente = 0,
    this.documentosPendientes = 0,
  });

  final int id;
  final String documento;

  /// DNI, RUC o CODIGO.
  final String tipoDoc;

  final String nombre;

  /// Segundo documento, siempre del tipo contrario al principal (un DNI con su
  /// RUC de persona natural, o un RUC con el DNI del dueño). Nulo si no tiene.
  final String? documentoAlterno;

  /// Tipo del segundo documento: DNI o RUC. Nulo si no hay segundo documento.
  final String? tipoDocAlterno;

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

  /// Vendedor a cargo, referencia al catalogo de usuarios.
  final int? vendedorId;

  /// Nombre del vendedor, solo para mostrar: no se envia al guardar.
  final String? vendedor;

  /// La categoría que le dio el último cálculo (A a F). Nula si aún no tiene.
  final String? categoriaCodigo;
  final String? categoriaNombre;
  final String? categoriaColor;

  /// Lo que debe hoy (ventas a crédito sin pagar del todo). Cero si no debe nada.
  /// Solo lo trae el selector de pedidos y notas de venta.
  final double deudaPendiente;

  /// En cuántos documentos se reparte esa deuda.
  final int documentosPendientes;

  /// "Saldo pendiente: S/ 47.20 en 1 documento"; nulo si no debe nada.
  String? get textoDeuda => deudaPendiente > 0
      ? 'Saldo pendiente: S/ ${deudaPendiente.toStringAsFixed(2)} en '
            '$documentosPendientes '
            '${documentosPendientes == 1 ? 'documento' : 'documentos'}'
      : null;

  final bool activo;

  /// "RUC 10458712039" o "DNI 45871203"; nulo si no tiene segundo documento.
  String? get textoDocumentoAlterno {
    final doc = documentoAlterno;
    if (doc == null || doc.isEmpty) return null;
    final tipo = tipoDocAlterno;
    return tipo == null || tipo.isEmpty ? doc : '$tipo $doc';
  }

  /// Texto contra el que se busca en la lista.
  String get buscable =>
      '$documento ${documentoAlterno ?? ''} $nombre ${direccion ?? ''} ${distrito ?? ''} ${mercado ?? ''} ${ruta ?? ''}'
          .toLowerCase();

  factory Cliente.desdeJson(Map<String, dynamic> json) => Cliente(
    id: json['id'] as int,
    documento: json['documento'] as String? ?? '',
    tipoDoc: json['tipoDoc'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    documentoAlterno: json['documentoAlterno'] as String?,
    tipoDocAlterno: json['tipoDocAlterno'] as String?,
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
    vendedorId: json['vendedorId'] as int?,
    vendedor: json['vendedor'] as String?,
    categoriaCodigo: json['categoriaCodigo'] as String?,
    categoriaNombre: json['categoriaNombre'] as String?,
    categoriaColor: json['categoriaColor'] as String?,
    deudaPendiente: (json['deudaPendiente'] as num?)?.toDouble() ?? 0,
    documentosPendientes: json['documentosPendientes'] as int? ?? 0,
    activo: json['activo'] as bool? ?? true,
  );

  Map<String, dynamic> aJson() => {
    'documento': documento,
    'tipoDoc': tipoDoc,
    'nombre': nombre,
    'documentoAlterno': documentoAlterno,
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
    String? documentoAlterno,
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
    documentoAlterno: documentoAlterno ?? this.documentoAlterno,
    tipoDocAlterno: tipoDocAlterno,
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
