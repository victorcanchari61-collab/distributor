/// Categoria de productos.
class Categoria {
  const Categoria({required this.id, required this.nombre, required this.activo});

  final int id;
  final String nombre;
  final bool activo;

  factory Categoria.desdeJson(Map<String, dynamic> json) => Categoria(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
  );
}

/// Marca de productos.
class Marca {
  const Marca({required this.id, required this.nombre, required this.activo});

  final int id;
  final String nombre;
  final bool activo;

  factory Marca.desdeJson(Map<String, dynamic> json) => Marca(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
  );
}

/// Unidad de medida: la base de todo producto y de sus presentaciones.
class UnidadMedida {
  const UnidadMedida({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.activo,
  });

  final int id;
  final String codigo;
  final String nombre;
  final bool activo;

  factory UnidadMedida.desdeJson(Map<String, dynamic> json) => UnidadMedida(
    id: json['id'] as int,
    codigo: json['codigo'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
  );
}
