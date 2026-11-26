import '../../../compartido/widgets/app_etiqueta.dart';

/// Estados de una cotizacion que mando un cliente desde el portal web.
abstract final class EstadoCotizacion {
  /// La mando el cliente y espera que el vendedor la jale a un pedido.
  static const enEspera = 'EN_ESPERA';

  /// Ya se jalo: hay un pedido que salio de ella.
  static const atendida = 'ATENDIDA';

  /// El vendedor no la va a atender (con su motivo).
  static const descartada = 'DESCARTADA';

  /// El cliente la retiro antes de que la atendieran.
  static const cancelada = 'CANCELADA';

  static String etiqueta(String estado) => switch (estado) {
    enEspera => 'En espera',
    atendida => 'Atendida',
    descartada => 'Descartada',
    cancelada => 'Cancelada',
    _ => estado,
  };

  static EtiquetaTono tono(String estado) => switch (estado) {
    enEspera => EtiquetaTono.aviso,
    atendida => EtiquetaTono.exito,
    descartada => EtiquetaTono.peligro,
    _ => EtiquetaTono.neutral,
  };
}

/// Una linea de la cotizacion: una presentacion del catalogo y cuantas.
class LineaCotizacion {
  const LineaCotizacion({
    required this.id,
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.presentacionId,
    required this.presentacion,
    required this.cantidad,
    required this.precioPresentacion,
    required this.subtotal,
  });

  final int id;
  final int productoId;
  final String codigo;
  final String producto;
  final int presentacionId;
  final String presentacion;

  /// Cuantas presentaciones (sacos, cajas...).
  final double cantidad;

  /// Precio de UNA presentacion, el que vio el cliente (referencial).
  final double precioPresentacion;
  final double subtotal;

  factory LineaCotizacion.desdeJson(Map<String, dynamic> json) =>
      LineaCotizacion(
        id: json['id'] as int,
        productoId: json['productoId'] as int,
        codigo: json['codigo'] as String? ?? '',
        producto: json['producto'] as String? ?? '',
        presentacionId: json['presentacionId'] as int,
        presentacion: json['presentacion'] as String? ?? '',
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
        precioPresentacion:
            (json['precioPresentacion'] as num?)?.toDouble() ?? 0,
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      );
}

/// Lo que un cliente armo en el portal web y le mando a su vendedor. No es un
/// pedido: el pedido lo crea el vendedor jalandola desde el formulario de
/// pedido, y al guardarlo queda atendida.
class Cotizacion {
  const Cotizacion({
    required this.id,
    required this.numero,
    required this.fecha,
    required this.estado,
    required this.clienteId,
    required this.cliente,
    required this.clienteDocumento,
    required this.total,
    required this.detalle,
    this.ruta,
    this.vendedor,
    this.listaPrecioId,
    this.nota,
    this.pedidoNumero,
    this.cerradaPor,
    this.motivoDescarte,
  });

  final int id;

  /// "CT-0001".
  final String numero;
  final DateTime fecha;
  final String estado;
  final int clienteId;
  final String cliente;
  final String clienteDocumento;
  final String? ruta;
  final String? vendedor;
  final int? listaPrecioId;

  /// Lo que el cliente quiso agregar: "para el jueves".
  final String? nota;
  final double total;

  /// El pedido que salio de ella, si ya se atendio.
  final String? pedidoNumero;
  final String? cerradaPor;
  final String? motivoDescarte;
  final List<LineaCotizacion> detalle;

  bool get enEspera => estado == EstadoCotizacion.enEspera;

  String get buscable =>
      '$numero $cliente $clienteDocumento ${ruta ?? ''}'.toLowerCase();

  factory Cotizacion.desdeJson(Map<String, dynamic> json) => Cotizacion(
    id: json['id'] as int,
    numero: json['numero'] as String? ?? '',
    fecha: DateTime.parse(json['fecha'] as String).toLocal(),
    estado: json['estado'] as String? ?? EstadoCotizacion.enEspera,
    clienteId: json['clienteId'] as int,
    cliente: json['cliente'] as String? ?? '',
    clienteDocumento: json['clienteDocumento'] as String? ?? '',
    ruta: json['ruta'] as String?,
    vendedor: json['vendedor'] as String?,
    listaPrecioId: json['listaPrecioId'] as int?,
    nota: json['nota'] as String?,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    pedidoNumero: json['pedidoNumero'] as String?,
    cerradaPor: json['cerradaPor'] as String?,
    motivoDescarte: json['motivoDescarte'] as String?,
    detalle: (json['detalle'] as List? ?? const [])
        .map((e) => LineaCotizacion.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}
