/// Una capa de costo dentro del stock de un producto: lo que entró en
/// determinado momento y a qué costo, en el orden en que se consume.
class CapaStock {
  const CapaStock({
    required this.id,
    required this.cantidadDisponible,
    required this.costoUnitario,
    required this.valor,
    required this.fecha,
  });

  final int id;
  final double cantidadDisponible;
  final double costoUnitario;
  final double valor;
  final DateTime fecha;

  factory CapaStock.desdeJson(Map<String, dynamic> json) => CapaStock(
    id: json['id'] as int,
    cantidadDisponible: (json['cantidadDisponible'] as num?)?.toDouble() ?? 0,
    costoUnitario: (json['costoUnitario'] as num?)?.toDouble() ?? 0,
    valor: (json['valor'] as num?)?.toDouble() ?? 0,
    fecha: DateTime.parse(json['fecha'] as String),
  );
}

/// Cuánto hay de un producto en un almacén (o sumado en todos), y a qué costo.
class Stock {
  const Stock({
    required this.productoId,
    required this.codigo,
    required this.producto,
    this.categoria,
    this.marca,
    required this.unidadBase,
    required this.almacenId,
    required this.almacen,
    required this.stock,
    required this.reservado,
    required this.disponible,
    required this.stockMinimo,
    required this.bajoMinimo,
    this.costoActual,
    this.costoUltimo,
    required this.valorizado,
    required this.capas,
  });

  final int productoId;
  final String codigo;
  final String producto;
  final String? categoria;
  final String? marca;
  final String unidadBase;
  final int almacenId;
  final String almacen;
  final double stock;

  /// Lo que apartan los pedidos Pendientes con reserva de stock activa.
  final double reservado;

  /// Stock menos lo reservado: lo que de verdad se puede prometer.
  final double disponible;

  final double stockMinimo;

  /// Debajo del mínimo: hay que reponer.
  final bool bajoMinimo;

  /// Costo de la capa más antigua: la que se consume ahora.
  final double? costoActual;
  final double? costoUltimo;
  final double valorizado;
  final List<CapaStock> capas;

  /// Texto contra el que se busca en la lista.
  String get buscable =>
      '$codigo $producto ${categoria ?? ''} ${marca ?? ''}'.toLowerCase();

  factory Stock.desdeJson(Map<String, dynamic> json) => Stock(
    productoId: json['productoId'] as int,
    codigo: json['codigo'] as String? ?? '',
    producto: json['producto'] as String? ?? '',
    categoria: json['categoria'] as String?,
    marca: json['marca'] as String?,
    unidadBase: json['unidadBase'] as String? ?? '',
    almacenId: json['almacenId'] as int,
    almacen: json['almacen'] as String? ?? '',
    stock: (json['stock'] as num?)?.toDouble() ?? 0,
    reservado: (json['reservado'] as num?)?.toDouble() ?? 0,
    disponible: (json['disponible'] as num?)?.toDouble() ?? 0,
    stockMinimo: (json['stockMinimo'] as num?)?.toDouble() ?? 0,
    bajoMinimo: json['bajoMinimo'] as bool? ?? false,
    costoActual: (json['costoActual'] as num?)?.toDouble(),
    costoUltimo: (json['costoUltimo'] as num?)?.toDouble(),
    valorizado: (json['valorizado'] as num?)?.toDouble() ?? 0,
    capas: (json['capas'] as List? ?? const [])
        .map((e) => CapaStock.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}
