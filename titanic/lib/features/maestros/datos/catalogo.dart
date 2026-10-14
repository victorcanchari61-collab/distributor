/// Lee un entero del JSON sin reventar si llega como double, texto o null.
int _entero(Object? valor) => switch (valor) {
  int v => v,
  num v => v.toInt(),
  String v => int.tryParse(v) ?? 0,
  _ => 0,
};

/// Categoria de productos.
class Categoria {
  const Categoria({
    required this.id,
    required this.nombre,
    required this.activo,
    this.descripcion,
    this.productos = 0,
  });

  final int id;
  final String nombre;
  final bool activo;

  /// Para qué es: "aceites, conservas". Opcional.
  final String? descripcion;

  /// Cuántos productos la usan. Con productos no se elimina, se desactiva.
  final int productos;

  factory Categoria.desdeJson(Map<String, dynamic> json) => Categoria(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
    descripcion: json['descripcion'] as String?,
    productos: _entero(json['productos']),
  );
}

/// Marca de productos.
class Marca {
  const Marca({
    required this.id,
    required this.nombre,
    required this.activo,
    this.productos = 0,
  });

  final int id;
  final String nombre;
  final bool activo;

  /// Cuántos productos la usan. Con productos no se elimina, se desactiva.
  final int productos;

  factory Marca.desdeJson(Map<String, dynamic> json) => Marca(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
    productos: _entero(json['productos']),
  );
}

/// Cómo se mide una unidad: se cuenta, se pesa o se mide. Los mismos valores
/// que el backend (`TipoUnidad`).
class TipoUnidad {
  const TipoUnidad._();

  static const conteo = 'CONTEO';
  static const peso = 'PESO';
  static const volumen = 'VOLUMEN';

  static const todos = [conteo, peso, volumen];

  static String etiqueta(String tipo) => switch (tipo) {
    conteo => 'Conteo',
    peso => 'Peso',
    volumen => 'Volumen',
    _ => tipo,
  };

  /// La aclaración del formulario, igual que en el panel web.
  static String nota(String tipo) => switch (tipo) {
    conteo => 'Se cuenta: unidad, saco, caja.',
    peso => 'Se pesa: kilo, gramo.',
    volumen => 'Se mide: litro, mililitro.',
    _ => '',
  };
}

/// Unidad de medida: la base de todo producto y de sus presentaciones.
class UnidadMedida {
  const UnidadMedida({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.activo,
    this.tipo = TipoUnidad.conteo,
    this.fraccionable = false,
    this.delSistema = false,
    this.usos = 0,
  });

  final int id;
  final String codigo;
  final String nombre;
  final bool activo;

  /// CONTEO, PESO o VOLUMEN ([TipoUnidad]).
  final String tipo;

  /// Admite decimales: 2.5 kilos sí, 2.5 sacos no.
  final bool fraccionable;

  /// Las que trae el sistema: no se eliminan.
  final bool delSistema;

  /// En cuántos productos o presentaciones se usa. Con usos no se elimina.
  final int usos;

  factory UnidadMedida.desdeJson(Map<String, dynamic> json) => UnidadMedida(
    id: json['id'] as int,
    codigo: json['codigo'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
    tipo: json['tipo'] as String? ?? TipoUnidad.conteo,
    fraccionable: json['fraccionable'] as bool? ?? false,
    delSistema: json['delSistema'] as bool? ?? false,
    usos: _entero(json['usos']),
  );
}
