import '../../../compartido/fechas.dart';

class TipoPrestamo {
  const TipoPrestamo._();

  /// Sale mercaderia propia.
  static const dado = 'DADO';

  /// Entra mercaderia de un tercero.
  static const recibido = 'RECIBIDO';
}

class EstadoPrestamo {
  const EstadoPrestamo._();
  static const pendiente = 'PENDIENTE';
  static const devuelto = 'DEVUELTO';
}

/// Una linea de un prestamo, con cuanto ya se devolvio.
class PrestamoDetalle {
  const PrestamoDetalle({
    required this.id,
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.unidadBase,
    this.presentacionId,
    this.presentacion,
    required this.cantidadPresentacion,
    required this.cantidad,
    required this.cantidadDevuelta,
    required this.cantidadPendiente,
    required this.costoUnitario,
    required this.costoTotal,
  });

  final int id;
  final int productoId;
  final String codigo;
  final String producto;
  final String unidadBase;

  final int? presentacionId;
  final String? presentacion;
  final double cantidadPresentacion;

  final double cantidad;
  final double cantidadDevuelta;

  /// Cantidad - CantidadDevuelta, en unidad base.
  final double cantidadPendiente;

  final double costoUnitario;
  final double costoTotal;

  factory PrestamoDetalle.desdeJson(Map<String, dynamic> json) =>
      PrestamoDetalle(
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
        cantidadDevuelta: (json['cantidadDevuelta'] as num?)?.toDouble() ?? 0,
        cantidadPendiente: (json['cantidadPendiente'] as num?)?.toDouble() ?? 0,
        costoUnitario: (json['costoUnitario'] as num?)?.toDouble() ?? 0,
        costoTotal: (json['costoTotal'] as num?)?.toDouble() ?? 0,
      );
}

/// Una linea dentro de una devolucion: que producto y cuanto.
class LineaDevolucionPrestamo {
  const LineaDevolucionPrestamo({
    required this.prestamoDetalleId,
    required this.producto,
    this.presentacion,
    required this.unidadBase,
    required this.cantidadPresentacion,
    required this.cantidad,
  });

  final int prestamoDetalleId;
  final String producto;
  final String? presentacion;
  final String unidadBase;
  final double cantidadPresentacion;
  final double cantidad;

  factory LineaDevolucionPrestamo.desdeJson(Map<String, dynamic> json) =>
      LineaDevolucionPrestamo(
        prestamoDetalleId: json['prestamoDetalleId'] as int,
        producto: json['producto'] as String? ?? '',
        presentacion: json['presentacion'] as String?,
        unidadBase: json['unidadBase'] as String? ?? '',
        cantidadPresentacion:
            (json['cantidadPresentacion'] as num?)?.toDouble() ?? 0,
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
      );
}

/// Una devolucion registrada: el documento que movio stock, con sus lineas.
/// El id es el del documento de inventario — por el se anula y se imprime.
class PrestamoDevolucion {
  const PrestamoDevolucion({
    required this.id,
    required this.numero,
    required this.fecha,
    required this.estado,
    this.almacenId = 0,
    this.almacen = '',
    this.usuario,
    required this.detalle,
  });

  final int id;
  final String numero;
  final DateTime fecha;

  /// CONFIRMADO o ANULADO.
  final String estado;

  /// A qué almacén entró (DADO) o de cuál salió (RECIBIDO). Hoy siempre el del préstamo.
  final int almacenId;
  final String almacen;

  final String? usuario;
  final List<LineaDevolucionPrestamo> detalle;

  bool get anulada => estado == 'ANULADO';

  factory PrestamoDevolucion.desdeJson(Map<String, dynamic> json) =>
      PrestamoDevolucion(
        id: json['id'] as int,
        numero: json['numero'] as String? ?? '',
        fecha: fechaDeJson(json['fecha'] as String),
        estado: json['estado'] as String? ?? 'CONFIRMADO',
        almacenId: json['almacenId'] as int? ?? 0,
        almacen: json['almacen'] as String? ?? '',
        usuario: json['usuario'] as String?,
        detalle: (json['detalle'] as List? ?? const [])
            .map(
              (e) =>
                  LineaDevolucionPrestamo.desdeJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
}

/// Mercaderia que sale o entra desde fuera de la empresa: se presta y se
/// espera de vuelta.
class Prestamo {
  const Prestamo({
    required this.id,
    required this.numero,
    required this.tipo,
    required this.contraparte,
    required this.almacenId,
    required this.almacen,
    required this.fecha,
    required this.estado,
    this.observacion,
    this.usuario,
    required this.total,
    required this.detalle,
    this.devoluciones = const [],
  });

  final int id;
  final String numero;

  /// DADO o RECIBIDO.
  final String tipo;

  final String contraparte;
  final int almacenId;
  final String almacen;
  final DateTime fecha;

  /// PENDIENTE o DEVUELTO.
  final String estado;

  final String? observacion;
  final String? usuario;

  /// Cuanto vale, al costo con que se registro.
  final double total;
  final List<PrestamoDetalle> detalle;

  /// Cada devolucion registrada, mas reciente primero — con su propio estado, por si se anulo.
  final List<PrestamoDevolucion> devoluciones;

  bool get esDado => tipo == TipoPrestamo.dado;

  String get buscable => '$numero $contraparte $almacen'.toLowerCase();

  factory Prestamo.desdeJson(Map<String, dynamic> json) => Prestamo(
    id: json['id'] as int,
    numero: json['numero'] as String? ?? '',
    tipo: json['tipo'] as String? ?? TipoPrestamo.dado,
    contraparte: json['contraparte'] as String? ?? '',
    almacenId: json['almacenId'] as int? ?? 0,
    almacen: json['almacen'] as String? ?? '',
    fecha: fechaDeJson(json['fecha'] as String),
    estado: json['estado'] as String? ?? EstadoPrestamo.pendiente,
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    detalle: (json['detalle'] as List? ?? const [])
        .map((e) => PrestamoDetalle.desdeJson(e as Map<String, dynamic>))
        .toList(),
    devoluciones: (json['devoluciones'] as List? ?? const [])
        .map((e) => PrestamoDevolucion.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}
