/// Una lista de precios: catalogo de a cuanto se vende cada presentacion.
class ListaPrecio {
  const ListaPrecio({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.esPredeterminada,
    required this.activo,
    required this.precios,
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final bool esPredeterminada;
  final bool activo;

  /// Cuantos precios tiene cargados.
  final int precios;

  String get buscable => '$nombre ${descripcion ?? ''}'.toLowerCase();

  factory ListaPrecio.desdeJson(Map<String, dynamic> json) => ListaPrecio(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String?,
    esPredeterminada: json['esPredeterminada'] as bool? ?? false,
    activo: json['activo'] as bool? ?? true,
    precios: json['precios'] as int? ?? 0,
  );
}

/// El precio de una presentacion dentro de una lista, con su escalon por
/// volumen (desde cuantas unidades aplica).
class Precio {
  const Precio({
    required this.id,
    required this.listaPrecioId,
    required this.listaPrecio,
    required this.presentacionId,
    required this.presentacion,
    required this.productoId,
    required this.producto,
    required this.precio,
    required this.cantidadMinima,
    required this.precioUnidadBase,
    required this.unidadBase,
    required this.activo,
    required this.fechaActualizacion,
  });

  final int id;
  final int listaPrecioId;
  final String listaPrecio;

  final int presentacionId;
  final String presentacion;

  final int productoId;
  final String producto;

  final double precio;

  /// Desde cuantas presentaciones aplica. 1 es el precio normal.
  final double cantidadMinima;

  /// Precio / factor: deja comparar el saco contra el kilo suelto.
  final double precioUnidadBase;
  final String unidadBase;

  final bool activo;
  final DateTime fechaActualizacion;

  String get buscable => '$producto $presentacion'.toLowerCase();

  factory Precio.desdeJson(Map<String, dynamic> json) => Precio(
    id: json['id'] as int,
    listaPrecioId: json['listaPrecioId'] as int,
    listaPrecio: json['listaPrecio'] as String? ?? '',
    presentacionId: json['presentacionId'] as int,
    presentacion: json['presentacion'] as String? ?? '',
    productoId: json['productoId'] as int,
    producto: json['producto'] as String? ?? '',
    precio: (json['precio'] as num?)?.toDouble() ?? 0,
    cantidadMinima: (json['cantidadMinima'] as num?)?.toDouble() ?? 1,
    precioUnidadBase: (json['precioUnidadBase'] as num?)?.toDouble() ?? 0,
    unidadBase: json['unidadBase'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
    fechaActualizacion: DateTime.parse(json['fechaActualizacion'] as String),
  );
}
