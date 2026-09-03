/// Cuántos días faltan para avisar "por vencer". Espejo de DIAS_ALERTA en el
/// panel web.
const diasAlertaVencimiento = 30;

/// Una capa con stock, vista desde "qué vence pronto" en vez de "qué tiene un
/// producto".
class Lote {
  const Lote({
    required this.capaId,
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.unidadBase,
    required this.almacenId,
    required this.almacen,
    this.lote,
    this.fechaVencimiento,
    this.diasParaVencer,
    required this.cantidadDisponible,
    required this.costoUnitario,
    required this.valor,
  });

  final int capaId;
  final int productoId;
  final String codigo;
  final String producto;
  final String unidadBase;
  final int almacenId;
  final String almacen;
  final String? lote;
  final DateTime? fechaVencimiento;

  /// Negativo si ya venció. Null si no tiene fecha de vencimiento.
  final int? diasParaVencer;

  final double cantidadDisponible;
  final double costoUnitario;
  final double valor;

  bool get vencido => diasParaVencer != null && diasParaVencer! < 0;
  bool get porVencer =>
      diasParaVencer != null &&
      diasParaVencer! >= 0 &&
      diasParaVencer! <= diasAlertaVencimiento;

  /// Texto contra el que se busca en la lista.
  String get buscable => '$codigo $producto ${lote ?? ''} $almacen'.toLowerCase();

  factory Lote.desdeJson(Map<String, dynamic> json) => Lote(
    capaId: json['capaId'] as int,
    productoId: json['productoId'] as int,
    codigo: json['codigo'] as String? ?? '',
    producto: json['producto'] as String? ?? '',
    unidadBase: json['unidadBase'] as String? ?? '',
    almacenId: json['almacenId'] as int,
    almacen: json['almacen'] as String? ?? '',
    lote: json['lote'] as String?,
    fechaVencimiento: json['fechaVencimiento'] == null
        ? null
        : DateTime.parse(json['fechaVencimiento'] as String),
    diasParaVencer: json['diasParaVencer'] as int?,
    cantidadDisponible: (json['cantidadDisponible'] as num?)?.toDouble() ?? 0,
    costoUnitario: (json['costoUnitario'] as num?)?.toDouble() ?? 0,
    valor: (json['valor'] as num?)?.toDouble() ?? 0,
  );
}
