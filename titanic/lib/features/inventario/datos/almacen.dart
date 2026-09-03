/// Almacen: donde se guarda la mercaderia.
class Almacen {
  const Almacen({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.direccion,
    required this.esPrincipal,
    required this.activo,
    required this.productos,
    required this.valorizado,
  });

  final int id;
  final String codigo;
  final String nombre;
  final String? direccion;

  /// El que recibe todo movimiento sin indicar otro. No se desactiva.
  final bool esPrincipal;

  final bool activo;

  /// Cuantos productos tienen stock ahi.
  final int productos;

  /// Cuanto vale la mercaderia que guarda, al costo.
  final double valorizado;

  /// Texto contra el que se busca en la lista.
  String get buscable => '$codigo $nombre ${direccion ?? ''}'.toLowerCase();

  factory Almacen.desdeJson(Map<String, dynamic> json) => Almacen(
    id: json['id'] as int,
    codigo: json['codigo'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    direccion: json['direccion'] as String?,
    esPrincipal: json['esPrincipal'] as bool? ?? false,
    activo: json['activo'] as bool? ?? true,
    productos: json['productos'] as int? ?? 0,
    valorizado: (json['valorizado'] as num?)?.toDouble() ?? 0,
  );
}
