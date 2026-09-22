import '../../../compartido/fechas.dart';

/// Por qué no se entregó algo: "Cliente no quiso", "Producto dañado",
/// "Faltó en el carro". Lo crea el dueño; se desactiva, no se borra.
class MotivoNovedad {
  const MotivoNovedad({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.regresaAlAlmacen = true,
    this.activo = true,
    this.usos = 0,
  });

  final int id;
  final String nombre;
  final String? descripcion;

  /// Salió en el camión y hay que esperarlo de vuelta. En falso, nunca salió
  /// del almacén (no se cargó, no alcanzó).
  final bool regresaAlAlmacen;

  final bool activo;

  /// En cuántas novedades se usó.
  final int usos;

  String get buscable => '$nombre ${descripcion ?? ''}'.toLowerCase();

  factory MotivoNovedad.desdeJson(Map<String, dynamic> json) => MotivoNovedad(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String?,
    // Las "opciones" para elegir al entregar no traen estos tres.
    regresaAlAlmacen: json['regresaAlAlmacen'] as bool? ?? true,
    activo: json['activo'] as bool? ?? true,
    usos: json['usos'] as int? ?? 0,
  );
}

/// LINEA: un producto se entregó en menos. PEDIDO: no se entregó el pedido entero.
class TipoNovedad {
  const TipoNovedad._();
  static const linea = 'LINEA';
  static const pedido = 'PEDIDO';
}

/// En qué va la revisión de lo que no se entregó.
class EstadoNovedad {
  const EstadoNovedad._();

  /// Volvió en el camión y nadie la contó todavía.
  static const pendiente = 'PENDIENTE';
  static const recibida = 'RECIBIDA';
  static const faltante = 'FALTANTE';

  /// El motivo dice que nunca salió del almacén: no hay nada que esperar.
  static const sinRetorno = 'SIN_RETORNO';
  static const anulada = 'ANULADA';

  static String texto(String estado) => switch (estado) {
    pendiente => 'Por revisar',
    recibida => 'Recibida',
    faltante => 'Faltante',
    sinRetorno => 'Sin retorno',
    anulada => 'Anulada',
    _ => estado,
  };
}

double _redondear(double n) => (n * 10000).round() / 10000;

String _numero(double n) {
  final r = _redondear(n);
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
}

/// Una cantidad en unidad base, dicha como se cuenta en el almacén: 113
/// unidades de una caja de 12 son "9 Caja 12UND + 5 UND".
String textoCantidad(
  double base,
  double factor,
  String? presentacion,
  String unidadBase,
) {
  if (factor <= 1 || presentacion == null)
    return '${_numero(base)} $unidadBase';

  final cajas = (base / factor + 1e-6).floor();
  final sueltas = _redondear(base - cajas * factor);
  final partes = <String>[
    if (cajas > 0) '$cajas $presentacion',
    if (sueltas > 0) '${_numero(sueltas)} $unidadBase',
  ];
  return partes.isEmpty ? '0 $unidadBase' : partes.join(' + ');
}

/// Una diferencia entre lo que el cliente pidió y lo que recibió.
class Novedad {
  const Novedad({
    required this.id,
    required this.tipo,
    required this.fecha,
    required this.estado,
    required this.pedidoId,
    required this.pedido,
    required this.cliente,
    this.despachoId,
    this.despacho,
    this.notaVenta,
    required this.productoId,
    required this.codigo,
    required this.producto,
    this.presentacion,
    required this.factor,
    required this.unidadBase,
    required this.cantidadPedida,
    required this.cantidadEntregada,
    required this.cantidadNoEntregada,
    required this.importe,
    required this.motivoId,
    required this.motivo,
    required this.regresaAlAlmacen,
    this.observacion,
    this.usuario,
    this.cantidadRegresada,
    this.verificadoPor,
    this.verificadoEn,
    this.observacionVerificacion,
  });

  final int id;

  /// LINEA o PEDIDO.
  final String tipo;
  final DateTime fecha;

  /// PENDIENTE, RECIBIDA, FALTANTE, SIN_RETORNO o ANULADA.
  final String estado;

  final int pedidoId;
  final String pedido;
  final String cliente;

  final int? despachoId;
  final String? despacho;
  final String? notaVenta;

  final int productoId;
  final String codigo;
  final String producto;

  /// En qué presentación se pidió: "Caja 12UND".
  final String? presentacion;
  final double factor;
  final String unidadBase;

  // Todo en unidad base: se muestra partido en cajas y sueltas.
  final double cantidadPedida;
  final double cantidadEntregada;
  final double cantidadNoEntregada;

  /// Cuánto valen S/ las unidades que no se entregaron.
  final double importe;

  final int motivoId;
  final String motivo;
  final bool regresaAlAlmacen;
  final String? observacion;
  final String? usuario;

  final double? cantidadRegresada;
  final String? verificadoPor;
  final DateTime? verificadoEn;
  final String? observacionVerificacion;

  bool get porRevisar => estado == EstadoNovedad.pendiente;
  bool get revisada =>
      estado == EstadoNovedad.recibida || estado == EstadoNovedad.faltante;

  String cantidad(double base) =>
      textoCantidad(base, factor, presentacion, unidadBase);

  String get buscable =>
      '$producto $codigo $pedido $cliente $motivo ${despacho ?? ''}'
          .toLowerCase();

  factory Novedad.desdeJson(Map<String, dynamic> json) => Novedad(
    id: json['id'] as int,
    tipo: json['tipo'] as String? ?? TipoNovedad.linea,
    fecha: fechaDeJson(json['fecha'] as String),
    estado: json['estado'] as String? ?? EstadoNovedad.pendiente,
    pedidoId: json['pedidoId'] as int,
    pedido: json['pedido'] as String? ?? '',
    cliente: json['cliente'] as String? ?? '',
    despachoId: json['despachoId'] as int?,
    despacho: json['despacho'] as String?,
    notaVenta: json['notaVenta'] as String?,
    productoId: json['productoId'] as int,
    codigo: json['codigo'] as String? ?? '',
    producto: json['producto'] as String? ?? '',
    presentacion: json['presentacion'] as String?,
    factor: (json['factor'] as num?)?.toDouble() ?? 1,
    unidadBase: json['unidadBase'] as String? ?? '',
    cantidadPedida: (json['cantidadPedida'] as num?)?.toDouble() ?? 0,
    cantidadEntregada: (json['cantidadEntregada'] as num?)?.toDouble() ?? 0,
    cantidadNoEntregada: (json['cantidadNoEntregada'] as num?)?.toDouble() ?? 0,
    importe: (json['importe'] as num?)?.toDouble() ?? 0,
    motivoId: json['motivoId'] as int,
    motivo: json['motivo'] as String? ?? '',
    regresaAlAlmacen: json['regresaAlAlmacen'] as bool? ?? true,
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    cantidadRegresada: (json['cantidadRegresada'] as num?)?.toDouble(),
    verificadoPor: json['verificadoPor'] as String?,
    verificadoEn: json['verificadoEn'] == null
        ? null
        : fechaDeJson(json['verificadoEn'] as String),
    observacionVerificacion: json['observacionVerificacion'] as String?,
  );
}

/// Contadores del listado completo, sin anuladas.
class ResumenNovedades {
  const ResumenNovedades({
    this.total = 0,
    this.porRevisar = 0,
    this.recibidas = 0,
    this.faltantes = 0,
    this.importe = 0,
  });

  final int total;

  /// Esperando que el encargado cuente lo que volvió.
  final int porRevisar;
  final int recibidas;
  final int faltantes;

  /// Cuánto valen S/ todas las unidades no entregadas.
  final double importe;

  factory ResumenNovedades.desdeJson(Map<String, dynamic> json) =>
      ResumenNovedades(
        total: json['total'] as int? ?? 0,
        porRevisar: json['porRevisar'] as int? ?? 0,
        recibidas: json['recibidas'] as int? ?? 0,
        faltantes: json['faltantes'] as int? ?? 0,
        importe: (json['importe'] as num?)?.toDouble() ?? 0,
      );
}
