/// Mercado donde se reparte un cliente: un mercado de abastos, pero también
/// puede ser una zona con tiendas o empresas — el nombre quedó "Mercado"
/// porque es como el negocio ya lo conoce.
class Mercado {
  const Mercado({
    required this.id,
    required this.nombre,
    this.direccion,
    this.distrito,
    required this.activo,
    this.clientes = 0,
  });

  final int id;
  final String nombre;
  final String? direccion;
  final String? distrito;
  final bool activo;

  /// Cuántos clientes ya lo usan. Si hay alguno, no se elimina.
  final int clientes;

  String get buscable => '$nombre ${direccion ?? ''} ${distrito ?? ''}'.toLowerCase();

  factory Mercado.desdeJson(Map<String, dynamic> json) => Mercado(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    direccion: json['direccion'] as String?,
    distrito: json['distrito'] as String?,
    activo: json['activo'] as bool? ?? true,
    clientes: json['clientes'] as int? ?? 0,
  );
}
