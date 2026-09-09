/// En qué situación está un documento respecto a hoy.
///
/// Los valores los manda el backend tal cual. NO se recalculan aquí: la misma
/// regla vive en un solo sitio y así la lista, el detalle y las alertas dicen
/// lo mismo.
class EstadoVencimiento {
  const EstadoVencimiento._();

  static const vencido = 'vencido';
  static const porVencer = 'porVencer';
  static const alDia = 'alDia';
  static const sinFecha = 'sinFecha';
}

/// Un documento con fecha de caducidad y cómo va.
class Vencimiento {
  const Vencimiento({
    required this.nombre,
    this.vence,
    this.diasRestantes,
    required this.estado,
  });

  final String nombre;
  final DateTime? vence;

  /// Días que faltan. Negativo si ya pasó.
  final int? diasRestantes;

  final String estado;

  /// "vence en 12 días", "venció hace 3 días", "vence hoy".
  String get plazo {
    final dias = diasRestantes;
    if (dias == null) return 'sin fecha';
    if (dias < 0) return 'venció hace ${-dias} ${-dias == 1 ? 'día' : 'días'}';
    if (dias == 0) return 'vence hoy';
    return 'vence en $dias ${dias == 1 ? 'día' : 'días'}';
  }

  factory Vencimiento.desdeJson(Map<String, dynamic> json) => Vencimiento(
    nombre: json['nombre'] as String? ?? '',
    vence: json['vence'] == null ? null : DateTime.parse(json['vence'] as String),
    diasRestantes: json['diasRestantes'] as int?,
    estado: json['estado'] as String? ?? EstadoVencimiento.sinFecha,
  );
}

/// Qué clase de vehículo es: camión, furgoneta, moto.
class TipoVehiculo {
  const TipoVehiculo({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.capacidadKgReferencia,
    required this.activo,
    this.vehiculos = 0,
  });

  final int id;
  final String nombre;
  final String? descripcion;

  /// Carga típica en kilos. Solo una sugerencia al dar de alta un vehículo.
  final double? capacidadKgReferencia;

  final bool activo;

  /// Cuántos vehículos son de este tipo. Si hay alguno, no se elimina.
  final int vehiculos;

  String get buscable => '$nombre ${descripcion ?? ''}'.toLowerCase();

  factory TipoVehiculo.desdeJson(Map<String, dynamic> json) => TipoVehiculo(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String?,
    capacidadKgReferencia: (json['capacidadKgReferencia'] as num?)?.toDouble(),
    activo: json['activo'] as bool? ?? true,
    vehiculos: json['vehiculos'] as int? ?? 0,
  );
}

/// Un vehículo de reparto.
class Vehiculo {
  const Vehiculo({
    required this.id,
    required this.placa,
    required this.tipoVehiculoId,
    required this.tipoVehiculo,
    this.marca,
    this.modelo,
    this.anio,
    this.color,
    this.capacidadKg,
    this.soatNumero,
    this.soatVence,
    this.revisionTecnicaVence,
    this.permisoCirculacionVence,
    this.foto,
    this.conductorId,
    this.conductor,
    this.observacion,
    required this.activo,
    this.vencimientos = const [],
    required this.estadoDocumentos,
  });

  final int id;
  final String placa;
  final int tipoVehiculoId;
  final String tipoVehiculo;
  final String? marca;
  final String? modelo;
  final int? anio;
  final String? color;
  final double? capacidadKg;

  final String? soatNumero;
  final DateTime? soatVence;
  final DateTime? revisionTecnicaVence;
  final DateTime? permisoCirculacionVence;

  /// Ruta relativa que sirve el backend, no el archivo.
  final String? foto;

  final int? conductorId;
  final String? conductor;
  final String? observacion;
  final bool activo;

  final List<Vencimiento> vencimientos;

  /// El peor estado de sus documentos: lo que decide si puede salir hoy.
  final String estadoDocumentos;

  String get descripcion =>
      [marca, modelo].where((t) => t != null && t.isNotEmpty).join(' ');

  String get buscable =>
      '$placa $tipoVehiculo ${marca ?? ''} ${modelo ?? ''} ${conductor ?? ''}'.toLowerCase();

  factory Vehiculo.desdeJson(Map<String, dynamic> json) => Vehiculo(
    id: json['id'] as int,
    placa: json['placa'] as String? ?? '',
    tipoVehiculoId: json['tipoVehiculoId'] as int? ?? 0,
    tipoVehiculo: json['tipoVehiculo'] as String? ?? '',
    marca: json['marca'] as String?,
    modelo: json['modelo'] as String?,
    anio: json['anio'] as int?,
    color: json['color'] as String?,
    capacidadKg: (json['capacidadKg'] as num?)?.toDouble(),
    soatNumero: json['soatNumero'] as String?,
    soatVence: json['soatVence'] == null ? null : DateTime.parse(json['soatVence'] as String),
    revisionTecnicaVence: json['revisionTecnicaVence'] == null
        ? null
        : DateTime.parse(json['revisionTecnicaVence'] as String),
    permisoCirculacionVence: json['permisoCirculacionVence'] == null
        ? null
        : DateTime.parse(json['permisoCirculacionVence'] as String),
    foto: json['foto'] as String?,
    conductorId: json['conductorId'] as int?,
    conductor: json['conductor'] as String?,
    observacion: json['observacion'] as String?,
    activo: json['activo'] as bool? ?? true,
    vencimientos: ((json['vencimientos'] as List?) ?? const [])
        .map((e) => Vencimiento.desdeJson(e as Map<String, dynamic>))
        .toList(),
    estadoDocumentos: json['estadoDocumentos'] as String? ?? EstadoVencimiento.sinFecha,
  );
}

/// Quien conduce.
class Conductor {
  const Conductor({
    required this.id,
    required this.nombre,
    required this.documento,
    this.telefono,
    this.direccion,
    this.licenciaNumero,
    this.licenciaCategoria,
    this.licenciaVence,
    this.foto,
    this.fechaIngreso,
    this.observacion,
    required this.activo,
    this.vehiculos = const [],
    this.vencimientos = const [],
    required this.estadoDocumentos,
  });

  final int id;
  final String nombre;
  final String documento;
  final String? telefono;
  final String? direccion;

  final String? licenciaNumero;
  final String? licenciaCategoria;
  final DateTime? licenciaVence;

  final String? foto;
  final DateTime? fechaIngreso;
  final String? observacion;
  final bool activo;

  /// Placas que tiene asignadas como conductor habitual.
  final List<String> vehiculos;

  final List<Vencimiento> vencimientos;
  final String estadoDocumentos;

  String get buscable =>
      '$nombre $documento ${telefono ?? ''} ${licenciaNumero ?? ''}'.toLowerCase();

  factory Conductor.desdeJson(Map<String, dynamic> json) => Conductor(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    documento: json['documento'] as String? ?? '',
    telefono: json['telefono'] as String?,
    direccion: json['direccion'] as String?,
    licenciaNumero: json['licenciaNumero'] as String?,
    licenciaCategoria: json['licenciaCategoria'] as String?,
    licenciaVence: json['licenciaVence'] == null
        ? null
        : DateTime.parse(json['licenciaVence'] as String),
    foto: json['foto'] as String?,
    fechaIngreso: json['fechaIngreso'] == null
        ? null
        : DateTime.parse(json['fechaIngreso'] as String),
    observacion: json['observacion'] as String?,
    activo: json['activo'] as bool? ?? true,
    vehiculos: ((json['vehiculos'] as List?) ?? const []).map((e) => e as String).toList(),
    vencimientos: ((json['vencimientos'] as List?) ?? const [])
        .map((e) => Vencimiento.desdeJson(e as Map<String, dynamic>))
        .toList(),
    estadoDocumentos: json['estadoDocumentos'] as String? ?? EstadoVencimiento.sinFecha,
  );
}

/// Los totales de la cabecera de Flota.
class ResumenFlota {
  const ResumenFlota({
    required this.vehiculos,
    required this.activos,
    required this.conDocumentoVencido,
    required this.porVencer,
  });

  final int vehiculos;
  final int activos;
  final int conDocumentoVencido;
  final int porVencer;

  factory ResumenFlota.desdeJson(Map<String, dynamic> json) => ResumenFlota(
    vehiculos: json['vehiculos'] as int? ?? 0,
    activos: json['activos'] as int? ?? 0,
    conDocumentoVencido: json['conDocumentoVencido'] as int? ?? 0,
    porVencer: json['porVencer'] as int? ?? 0,
  );
}

/// Los totales de la cabecera de Conductores.
class ResumenConductores {
  const ResumenConductores({
    required this.conductores,
    required this.activos,
    required this.conLicenciaVencida,
    required this.porVencer,
  });

  final int conductores;
  final int activos;
  final int conLicenciaVencida;
  final int porVencer;

  factory ResumenConductores.desdeJson(Map<String, dynamic> json) => ResumenConductores(
    conductores: json['conductores'] as int? ?? 0,
    activos: json['activos'] as int? ?? 0,
    conLicenciaVencida: json['conLicenciaVencida'] as int? ?? 0,
    porVencer: json['porVencer'] as int? ?? 0,
  );
}
