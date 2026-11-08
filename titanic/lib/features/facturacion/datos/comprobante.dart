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

  /// SUNAT aceptó la comunicación de baja: la factura ya no vale.
  static const baja = 'BAJA';

  static String etiqueta(String estado) => switch (estado) {
    aceptado => 'Aceptado',
    rechazado => 'Rechazado',
    generado => 'Sin enviar',
    baja => 'Dado de baja',
    _ => 'Sin respuesta',
  };

  /// Qué significa cada estado, igual que la ayuda del panel web.
  static String ayuda(String estado) => switch (estado) {
    aceptado => 'SUNAT lo aceptó.',
    rechazado => 'SUNAT lo rechazó: el motivo está en el CDR.',
    generado => 'Está firmado pero todavía no llegó a SUNAT.',
    baja => 'SUNAT aceptó la baja: la factura ya no vale.',
    _ => 'El envío falló antes de tener respuesta: se puede reenviar.',
  };
}

/// En qué quedó la comunicación de baja de una factura.
class EstadoBajaCpe {
  const EstadoBajaCpe._();
  static const pendiente = 'PENDIENTE';
  static const aceptada = 'ACEPTADA';
  static const rechazada = 'RECHAZADA';

  static String etiqueta(String estado) => switch (estado) {
    pendiente => 'Baja pendiente',
    aceptada => 'Baja aceptada',
    rechazada => 'Baja rechazada',
    _ => estado,
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

/// Una línea de un comprobante, tal como salió.
class LineaComprobante {
  const LineaComprobante({
    required this.descripcion,
    required this.cantidad,
    required this.precio,
    required this.afectoIgv,
  });

  factory LineaComprobante.desdeJson(Map<String, dynamic> j) =>
      LineaComprobante(
        descripcion: j['descripcion'] as String? ?? '',
        cantidad: (j['cantidad'] as num).toDouble(),
        precio: (j['precio'] as num).toDouble(),
        afectoIgv: j['afectoIgv'] as bool? ?? true,
      );

  final String descripcion;
  final double cantidad;

  /// Por unidad, con IGV si la línea es gravada.
  final double precio;
  final bool afectoIgv;
}

/// Los motivos de SUNAT (Catálogos 09 y 10): lo que se elige al corregir un comprobante.
class MotivoNota {
  const MotivoNota(this.codigo, this.etiqueta);
  final String codigo;
  final String etiqueta;
}

class MotivosNota {
  const MotivosNota._();

  static List<MotivoNota> de(String tipo) =>
      tipo == TipoCpe.notaCredito ? _credito : _debito;

  static const _credito = [
    MotivoNota('01', 'Anulación de la operación'),
    MotivoNota('02', 'Anulación por error en el RUC'),
    MotivoNota('03', 'Corrección por error en la descripción'),
    MotivoNota('04', 'Descuento global'),
    MotivoNota('05', 'Descuento por ítem'),
    MotivoNota('06', 'Devolución total'),
    MotivoNota('07', 'Devolución por ítem'),
    MotivoNota('08', 'Bonificación'),
    MotivoNota('09', 'Disminución en el valor'),
    MotivoNota('13', 'Ajustes de montos y/o fechas de pago'),
  ];

  static const _debito = [
    MotivoNota('01', 'Intereses por mora'),
    MotivoNota('02', 'Aumento en el valor'),
    MotivoNota('03', 'Penalidades u otros conceptos'),
  ];
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
    this.ventaDirecta = false,
    this.afectadoNumero,
    this.codMotivo,
    this.desMotivo,
    this.mensajeSunat,
    this.tieneCdr = false,
    this.nombreArchivo = '',
    this.lineas = const [],
    this.whatsAppEstado,
    this.whatsAppTelefono,
    this.whatsAppEnviadoEn,
    this.whatsAppError,
    this.notas = const [],
    this.bajaEstado,
    this.bajaMotivo,
    this.bajaFecha,
    this.bajaMensaje,
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
    ventaDirecta: j['ventaDirecta'] as bool? ?? false,
    afectadoNumero: j['afectadoNumero'] as String?,
    codMotivo: j['codMotivo'] as String?,
    desMotivo: j['desMotivo'] as String?,
    mensajeSunat: j['mensajeSunat'] as String?,
    tieneCdr: j['tieneCdr'] as bool? ?? false,
    nombreArchivo: j['nombreArchivo'] as String? ?? '',
    lineas: [
      for (final l in (j['lineas'] as List? ?? const []))
        LineaComprobante.desdeJson(l as Map<String, dynamic>),
    ],
    whatsAppEstado: j['whatsAppEstado'] as String?,
    whatsAppTelefono: j['whatsAppTelefono'] as String?,
    whatsAppEnviadoEn: fechaDeJsonOpcional(j['whatsAppEnviadoEn']),
    whatsAppError: j['whatsAppError'] as String?,
    notas: [
      for (final n in (j['notas'] as List? ?? const []))
        NotaDeComprobante.desdeJson(n as Map<String, dynamic>),
    ],
    bajaEstado: j['bajaEstado'] as String?,
    bajaMotivo: j['bajaMotivo'] as String?,
    bajaFecha: fechaDeJsonOpcional(j['bajaFecha']),
    bajaMensaje: j['bajaMensaje'] as String?,
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

  /// La nota de venta de la que salió; nulo si nació directa ([ventaDirecta]).
  final String? notaVentaNumero;

  /// Nació como factura o boleta directa: no tiene nota de venta que mostrar.
  final bool ventaDirecta;

  /// Solo en notas: el comprobante que corrigen.
  final String? afectadoNumero;
  final String? codMotivo;
  final String? desMotivo;
  final String? mensajeSunat;
  final bool tieneCdr;

  /// 10761659621-03-B001-3: el nombre de sus archivos (XML y CDR), sin extension.
  final String nombreArchivo;

  /// Las lineas que salieron: de ahi arranca una nota de credito.
  final List<LineaComprobante> lineas;

  final String? whatsAppEstado;
  final String? whatsAppTelefono;
  final DateTime? whatsAppEnviadoEn;
  final String? whatsAppError;

  /// Solo en facturas y boletas: las notas que las corrigen.
  final List<NotaDeComprobante> notas;

  /// En qué quedó la baja (PENDIENTE, ACEPTADA, RECHAZADA); nulo si nunca se pidió.
  final String? bajaEstado;
  final String? bajaMotivo;
  final DateTime? bajaFecha;
  final String? bajaMensaje;

  /// Cuántos días de emitida admite SUNAT la baja de una factura.
  static const diasParaBaja = 7;

  /// Se puede pedir la baja: solo una factura aceptada, sin baja en trámite, emitida hace [diasParaBaja] días o menos
  /// y sin notas de crédito o débito aceptadas. Quien llama además comprueba el permiso `anular`.
  bool puedeDarDeBaja(DateTime hoy) {
    if (tipo != TipoCpe.factura || estado != EstadoCpe.aceptado) return false;
    if (bajaEstado == EstadoBajaCpe.pendiente) return false;
    if (notas.any((n) => n.estado == EstadoCpe.aceptado)) return false;

    final emitida = DateTime.utc(
      fechaEmision.year,
      fechaEmision.month,
      fechaEmision.day,
    );
    final hoyDia = DateTime.utc(hoy.year, hoy.month, hoy.day);
    return hoyDia.difference(emitida).inDays <= diasParaBaja;
  }

  /// El aviso de la hoja de baja: qué pasa con la venta si SUNAT la acepta.
  String get avisoBaja => ventaDirecta
      ? 'Si SUNAT la acepta, la factura deja de valer: el stock vuelve al '
            'almacén y deja de contar en los reportes.'
      : notaVentaNumero != null
      ? 'Si SUNAT la acepta, la venta $notaVentaNumero se anula: el stock '
            'vuelve al almacén y deja de contar en los reportes.'
      : 'Si SUNAT la acepta, la factura deja de valer.';

  /// El aviso de una nota de crédito de anulación o devolución total; nulo si no hay venta que se anule.
  String? get avisoNotaTotal {
    if (ventaDirecta) {
      return 'Si SUNAT la acepta y cubre todo lo facturado, el stock vuelve '
          'al almacén y deja de contar en los reportes.';
    }
    if (notaVentaNumero != null) {
      return 'Si SUNAT la acepta y cubre todo lo facturado, la venta '
          '$notaVentaNumero se anula: el stock vuelve al almacén y deja de '
          'contar en los reportes.';
    }
    return null;
  }

  bool get aceptado => estado == EstadoCpe.aceptado;
  bool get esPrueba => entorno != 'produccion';

  /// Lo que busca el buscador de la lista.
  String get buscable =>
      '$numeroCompleto $clienteNombre $clienteDocumento ${notaVentaNumero ?? ''}'
          .toLowerCase();
}
