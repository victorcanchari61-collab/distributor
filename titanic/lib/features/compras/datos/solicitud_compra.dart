import '../../../compartido/fechas.dart';

class EstadoSolicitudCompra {
  const EstadoSolicitudCompra._();

  /// Se esta armando: solo la ve quien la pidio. Se envia al administrador cuando esta lista.
  static const borrador = 'BORRADOR';
  static const pendiente = 'PENDIENTE';
  static const atendida = 'ATENDIDA';
  static const rechazada = 'RECHAZADA';
  static const anulada = 'ANULADA';
}

class UrgenciaSolicitud {
  const UrgenciaSolicitud._();
  static const normal = 'NORMAL';
  static const urgente = 'URGENTE';
}

/// Una orden de compra que nació de la solicitud.
class OrdenDeSolicitud {
  const OrdenDeSolicitud({
    required this.id,
    required this.numero,
    required this.estado,
  });

  final int id;
  final String numero;
  final String estado;

  factory OrdenDeSolicitud.desdeJson(Map<String, dynamic> json) =>
      OrdenDeSolicitud(
        id: json['id'] as int,
        numero: json['numero'] as String? ?? '',
        estado: json['estado'] as String? ?? '',
      );
}

/// Un producto pedido, en la presentación y cantidad que escribió quien lo pide. Sin costo: ese lo pone Compras.
class LineaSolicitud {
  const LineaSolicitud({
    required this.id,
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.unidadBase,
    this.presentacionId,
    this.presentacion,
    required this.cantidadPresentacion,
    required this.cantidad,
    this.nota,
  });

  final int id;
  final int productoId;
  final String codigo;
  final String producto;
  final String unidadBase;
  final int? presentacionId;
  final String? presentacion;
  final double cantidadPresentacion;

  /// En unidad base.
  final double cantidad;
  final String? nota;

  factory LineaSolicitud.desdeJson(Map<String, dynamic> json) => LineaSolicitud(
    id: json['id'] as int,
    productoId: json['productoId'] as int,
    codigo: json['codigo'] as String? ?? '',
    producto: json['producto'] as String? ?? '',
    unidadBase: json['unidadBase'] as String? ?? '',
    presentacionId: json['presentacionId'] as int?,
    presentacion: json['presentacion'] as String?,
    cantidadPresentacion:
        (json['cantidadPresentacion'] as num?)?.toDouble() ?? 0,
    cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
    nota: json['nota'] as String?,
  );
}

/// Lo que el almacén pide que se compre: un documento interno. De él Compras arma la orden de compra, que es la que
/// se le envía al proveedor.
class SolicitudCompra {
  const SolicitudCompra({
    required this.id,
    required this.numero,
    required this.fecha,
    required this.almacenId,
    required this.almacen,
    required this.urgencia,
    required this.estado,
    this.observacion,
    this.motivoRechazo,
    this.usuarioId,
    this.solicitante,
    required this.lineas,
    required this.ordenes,
    required this.detalle,
  });

  final int id;
  final String numero;
  final DateTime fecha;
  final int almacenId;
  final String almacen;

  /// NORMAL o URGENTE.
  final String urgencia;

  /// PENDIENTE, ATENDIDA, RECHAZADA o ANULADA.
  final String estado;
  final String? observacion;

  /// Por qué Compras la rechazó. Solo cuando está rechazada.
  final String? motivoRechazo;
  final int? usuarioId;
  final String? solicitante;
  final int lineas;

  /// Las órdenes de compra que se hicieron con ella.
  final List<OrdenDeSolicitud> ordenes;

  /// Las líneas. El listado no las trae (queda vacío): se piden al abrir la solicitud.
  final List<LineaSolicitud> detalle;

  bool get esUrgente => urgencia == UrgenciaSolicitud.urgente;
  bool get estaPendiente => estado == EstadoSolicitudCompra.pendiente;
  bool get esBorrador => estado == EstadoSolicitudCompra.borrador;

  /// Se corrige o se anula mientras es borrador o esta pendiente.
  bool get seEdita => esBorrador || estaPendiente;

  String get buscable =>
      '$numero $almacen ${solicitante ?? ''} ${ordenes.map((o) => o.numero).join(' ')}'
          .toLowerCase();

  factory SolicitudCompra.desdeJson(Map<String, dynamic> json) =>
      SolicitudCompra(
        id: json['id'] as int,
        numero: json['numero'] as String? ?? '',
        fecha: fechaDeJson(json['fecha'] as String),
        almacenId: json['almacenId'] as int? ?? 0,
        almacen: json['almacen'] as String? ?? '',
        urgencia: json['urgencia'] as String? ?? UrgenciaSolicitud.normal,
        estado: json['estado'] as String? ?? EstadoSolicitudCompra.pendiente,
        observacion: json['observacion'] as String?,
        motivoRechazo: json['motivoRechazo'] as String?,
        usuarioId: json['usuarioId'] as int?,
        solicitante: json['solicitante'] as String?,
        lineas: json['lineas'] as int? ?? 0,
        ordenes: (json['ordenes'] as List? ?? const [])
            .map((e) => OrdenDeSolicitud.desdeJson(e as Map<String, dynamic>))
            .toList(),
        detalle: (json['detalle'] as List? ?? const [])
            .map((e) => LineaSolicitud.desdeJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Un producto del almacén que está bajo su mínimo, con lo que se sugiere pedir (en unidad base).
class SugerenciaSolicitud {
  const SugerenciaSolicitud({
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.unidadBase,
    required this.stock,
    required this.stockMinimo,
    required this.cantidadSugerida,
  });

  final int productoId;
  final String codigo;
  final String producto;
  final String unidadBase;
  final double stock;
  final double stockMinimo;
  final double cantidadSugerida;

  factory SugerenciaSolicitud.desdeJson(Map<String, dynamic> json) =>
      SugerenciaSolicitud(
        productoId: json['productoId'] as int,
        codigo: json['codigo'] as String? ?? '',
        producto: json['producto'] as String? ?? '',
        unidadBase: json['unidadBase'] as String? ?? '',
        stock: (json['stock'] as num?)?.toDouble() ?? 0,
        stockMinimo: (json['stockMinimo'] as num?)?.toDouble() ?? 0,
        cantidadSugerida: (json['cantidadSugerida'] as num?)?.toDouble() ?? 0,
      );
}
