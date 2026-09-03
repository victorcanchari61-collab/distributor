/// Una linea de un documento de inventario (recepcion, ajuste, transferencia).
class LineaDocumento {
  const LineaDocumento({
    required this.id,
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.unidadBase,
    this.presentacionId,
    this.presentacion,
    required this.cantidadPresentacion,
    required this.cantidad,
    required this.costoUnitario,
    required this.costoTotal,
    required this.tipo,
    required this.almacenId,
    required this.almacen,
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
  final double costoUnitario;
  final double costoTotal;

  /// ENTRADA o SALIDA: en una transferencia hay lineas de los dos tipos.
  final String tipo;
  final int almacenId;
  final String almacen;

  bool get esEntrada => tipo == 'ENTRADA';

  factory LineaDocumento.desdeJson(Map<String, dynamic> json) => LineaDocumento(
    id: json['id'] as int,
    productoId: json['productoId'] as int,
    codigo: json['codigo'] as String? ?? '',
    producto: json['producto'] as String? ?? '',
    unidadBase: json['unidadBase'] as String? ?? '',
    presentacionId: json['presentacionId'] as int?,
    presentacion: json['presentacion'] as String?,
    cantidadPresentacion: (json['cantidadPresentacion'] as num?)?.toDouble() ?? 0,
    cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
    costoUnitario: (json['costoUnitario'] as num?)?.toDouble() ?? 0,
    costoTotal: (json['costoTotal'] as num?)?.toDouble() ?? 0,
    tipo: json['tipo'] as String? ?? 'ENTRADA',
    almacenId: json['almacenId'] as int? ?? 0,
    almacen: json['almacen'] as String? ?? '',
  );
}

/// Un documento de movimiento de inventario: recepcion, ajuste o
/// transferencia. La misma forma sirve para los tres, solo cambia `tipo`.
class DocumentoInventario {
  const DocumentoInventario({
    required this.id,
    required this.numero,
    required this.tipo,
    required this.fecha,
    required this.almacenId,
    required this.almacen,
    this.almacenDestinoId,
    this.almacenDestino,
    this.compraId,
    this.compra,
    required this.motivoId,
    required this.motivo,
    required this.motivoTipo,
    required this.estado,
    this.observacion,
    this.usuario,
    this.anuladoPor,
    required this.total,
    required this.lineas,
    required this.detalle,
  });

  final int id;
  final String numero;
  final String tipo;
  final DateTime fecha;

  final int almacenId;
  final String almacen;

  /// Solo en transferencias: el almacen que recibe.
  final int? almacenDestinoId;
  final String? almacenDestino;

  /// Solo en recepciones: la compra que se esta descargando.
  final int? compraId;
  final String? compra;

  final int motivoId;
  final String motivo;
  final String motivoTipo;

  final String estado;
  final String? observacion;
  final String? usuario;

  /// Numero del documento que lo anulo, si lo hay.
  final String? anuladoPor;

  final double total;
  final int lineas;
  final List<LineaDocumento> detalle;

  bool get anulado => estado == 'ANULADO';

  String get buscable => '$numero $almacen $motivo ${compra ?? ''}'.toLowerCase();

  factory DocumentoInventario.desdeJson(Map<String, dynamic> json) => DocumentoInventario(
    id: json['id'] as int,
    numero: json['numero'] as String? ?? '',
    tipo: json['tipo'] as String? ?? '',
    fecha: DateTime.parse(json['fecha'] as String),
    almacenId: json['almacenId'] as int? ?? 0,
    almacen: json['almacen'] as String? ?? '',
    almacenDestinoId: json['almacenDestinoId'] as int?,
    almacenDestino: json['almacenDestino'] as String?,
    compraId: json['compraId'] as int?,
    compra: json['compra'] as String?,
    motivoId: json['motivoId'] as int? ?? 0,
    motivo: json['motivo'] as String? ?? '',
    motivoTipo: json['motivoTipo'] as String? ?? '',
    estado: json['estado'] as String? ?? 'CONFIRMADO',
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    anuladoPor: json['anuladoPor'] as String?,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    lineas: json['lineas'] as int? ?? 0,
    detalle: (json['detalle'] as List? ?? const [])
        .map((e) => LineaDocumento.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}
