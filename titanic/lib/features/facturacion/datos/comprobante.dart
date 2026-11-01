import '../../../compartido/fechas.dart';

/// Los tipos de comprobante electrónico (Catálogo 01 de SUNAT).
class TipoCpe {
  const TipoCpe._();
  static const factura = '01';
  static const boleta = '03';
  static const notaCredito = '07';
  static const notaDebito = '08';

  /// El submódulo de permisos de cada tipo: los mismos ids del menú.
  static String submodulo(String tipo) => switch (tipo) {
    factura => 'fact.facturas',
    boleta => 'fact.boletas',
    notaCredito => 'fact.notascredito',
    _ => 'fact.notasdebito',
  };

  static String corto(String tipo) => switch (tipo) {
    factura => 'Factura',
    boleta => 'Boleta',
    notaCredito => 'Nota de crédito',
    _ => 'Nota de débito',
  };
}

/// En qué quedó el comprobante frente a SUNAT.
class EstadoCpe {
  const EstadoCpe._();
  static const aceptado = 'ACEPTADO';
  static const rechazado = 'RECHAZADO';
  static const generado = 'GENERADO';
  static const error = 'ERROR';

  static String etiqueta(String estado) => switch (estado) {
    aceptado => 'Aceptado',
    rechazado => 'Rechazado',
    generado => 'Sin enviar',
    _ => 'Sin respuesta',
  };
}

/// En qué quedó el envío por WhatsApp.
class EstadoWhatsAppCpe {
  const EstadoWhatsAppCpe._();
  static const encolado = 'ENCOLADO';
  static const error = 'ERROR';
  static const sinTelefono = 'SIN_TELEFONO';

  static String etiqueta(String? estado) => switch (estado) {
    encolado => 'Enviado',
    error => 'Falló',
    sinTelefono => 'Sin teléfono',
    _ => 'Sin enviar',
  };
}

/// Una nota de crédito o débito dentro de la factura o boleta que corrige.
class NotaDeComprobante {
  const NotaDeComprobante({
    required this.id,
    required this.tipo,
    required this.numeroCompleto,
    required this.estado,
    required this.total,
  });

  factory NotaDeComprobante.desdeJson(Map<String, dynamic> j) =>
      NotaDeComprobante(
        id: j['id'] as int,
        tipo: j['tipo'] as String,
        numeroCompleto: j['numeroCompleto'] as String,
        estado: j['estado'] as String,
        total: (j['total'] as num).toDouble(),
      );

  final int id;
  final String tipo;
  final String numeroCompleto;
  final String estado;
  final double total;
}

/// Un comprobante electrónico emitido: factura, boleta o nota.
class Comprobante {
  const Comprobante({
    required this.id,
    required this.tipo,
    required this.numeroCompleto,
    required this.fechaEmision,
    required this.clienteNombre,
    required this.clienteDocumento,
    required this.total,
    required this.estado,
    required this.entorno,
    this.clienteId,
    this.clienteTelefono,
    this.notaVentaNumero,
    this.afectadoNumero,
    this.codMotivo,
    this.desMotivo,
    this.mensajeSunat,
    this.tieneCdr = false,
    this.whatsAppEstado,
    this.whatsAppTelefono,
    this.whatsAppEnviadoEn,
    this.whatsAppError,
    this.notas = const [],
  });

  factory Comprobante.desdeJson(Map<String, dynamic> j) => Comprobante(
    id: j['id'] as int,
    tipo: j['tipo'] as String,
    numeroCompleto: j['numeroCompleto'] as String,
    fechaEmision: fechaDeJson(j['fechaEmision'] as String),
    clienteNombre: j['clienteNombre'] as String,
    clienteDocumento: j['clienteDocumento'] as String,
    total: (j['total'] as num).toDouble(),
    estado: j['estado'] as String,
    entorno: j['entorno'] as String,
    clienteId: j['clienteId'] as int?,
    clienteTelefono: j['clienteTelefono'] as String?,
    notaVentaNumero: j['notaVentaNumero'] as String?,
    afectadoNumero: j['afectadoNumero'] as String?,
    codMotivo: j['codMotivo'] as String?,
    desMotivo: j['desMotivo'] as String?,
    mensajeSunat: j['mensajeSunat'] as String?,
    tieneCdr: j['tieneCdr'] as bool? ?? false,
    whatsAppEstado: j['whatsAppEstado'] as String?,
    whatsAppTelefono: j['whatsAppTelefono'] as String?,
    whatsAppEnviadoEn: fechaDeJsonOpcional(j['whatsAppEnviadoEn']),
    whatsAppError: j['whatsAppError'] as String?,
    notas: [
      for (final n in (j['notas'] as List? ?? const []))
        NotaDeComprobante.desdeJson(n as Map<String, dynamic>),
    ],
  );

  final int id;
  final String tipo;
  final String numeroCompleto;
  final DateTime fechaEmision;
  final String clienteNombre;
  final String clienteDocumento;
  final double total;
  final String estado;

  /// beta (pruebas) o produccion.
  final String entorno;

  final int? clienteId;

  /// El teléfono que hoy tiene el cliente: el que se propone al enviar.
  final String? clienteTelefono;

  final String? notaVentaNumero;

  /// Solo en notas: el comprobante que corrigen.
  final String? afectadoNumero;
  final String? codMotivo;
  final String? desMotivo;
  final String? mensajeSunat;
  final bool tieneCdr;

  final String? whatsAppEstado;
  final String? whatsAppTelefono;
  final DateTime? whatsAppEnviadoEn;
  final String? whatsAppError;

  /// Solo en facturas y boletas: las notas que las corrigen.
  final List<NotaDeComprobante> notas;

  bool get aceptado => estado == EstadoCpe.aceptado;
  bool get esPrueba => entorno != 'produccion';

  /// Lo que busca el buscador de la lista.
  String get buscable =>
      '$numeroCompleto $clienteNombre $clienteDocumento ${notaVentaNumero ?? ''}'
          .toLowerCase();
}
