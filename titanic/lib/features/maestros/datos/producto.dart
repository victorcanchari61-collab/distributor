/// Una forma de comprar o vender un producto: saco de 50, caja x12.
class Presentacion {
  const Presentacion({
    required this.id,
    required this.unidadId,
    required this.unidad,
    required this.nombre,
    required this.factor,
    required this.esBase,
    required this.esCompra,
    required this.esVenta,
    required this.activo,
  });

  final int id;
  final int unidadId;
  final String unidad;
  final String nombre;

  /// Cuantas unidades base equivale. Un saco de 50 kg tiene factor 50.
  final double factor;

  /// La de factor 1: la crea sola el backend y no se elimina ni cambia.
  final bool esBase;
  final bool esCompra;
  final bool esVenta;
  final bool activo;

  factory Presentacion.desdeJson(Map<String, dynamic> json) => Presentacion(
    id: json['id'] as int,
    unidadId: json['unidadId'] as int,
    unidad: json['unidad'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    factor: (json['factor'] as num?)?.toDouble() ?? 1,
    esBase: json['esBase'] as bool? ?? false,
    esCompra: json['esCompra'] as bool? ?? true,
    esVenta: json['esVenta'] as bool? ?? true,
    activo: json['activo'] as bool? ?? true,
  );
}

/// Producto: lo que se compra y se vende.
class Producto {
  const Producto({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    this.categoriaId,
    this.categoria,
    this.marcaId,
    this.marca,
    required this.unidadBaseId,
    required this.unidadBase,
    this.costoReferencia,
    required this.controlaStock,
    required this.stockMinimo,
    required this.activo,
    required this.presentaciones,
  });

  final int id;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final int? categoriaId;
  final String? categoria;
  final int? marcaId;
  final String? marca;
  final int unidadBaseId;

  /// Codigo de la unidad en la que se lleva el stock: KG, UND, LT.
  final String unidadBase;

  /// Lo que suele costar una unidad base. Referencia, no el costo del stock.
  final double? costoReferencia;

  final bool controlaStock;
  final double stockMinimo;
  final bool activo;
  final List<Presentacion> presentaciones;

  /// Texto contra el que se busca en la lista.
  String get buscable =>
      '$codigo $nombre ${categoria ?? ''} ${marca ?? ''}'.toLowerCase();

  factory Producto.desdeJson(Map<String, dynamic> json) => Producto(
    id: json['id'] as int,
    codigo: json['codigo'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String?,
    categoriaId: json['categoriaId'] as int?,
    categoria: json['categoria'] as String?,
    marcaId: json['marcaId'] as int?,
    marca: json['marca'] as String?,
    unidadBaseId: json['unidadBaseId'] as int,
    unidadBase: json['unidadBase'] as String? ?? '',
    costoReferencia: (json['costoReferencia'] as num?)?.toDouble(),
    controlaStock: json['controlaStock'] as bool? ?? true,
    stockMinimo: (json['stockMinimo'] as num?)?.toDouble() ?? 0,
    activo: json['activo'] as bool? ?? true,
    presentaciones: (json['presentaciones'] as List? ?? const [])
        .map((e) => Presentacion.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}
