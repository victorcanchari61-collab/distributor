/// Ruta de reparto a la que pertenece un cliente.
class Ruta {
  const Ruta({
    required this.id,
    required this.nombre,
    required this.activo,
    this.clientes = 0,
  });

  final int id;
  final String nombre;
  final bool activo;

  /// Cuántos clientes ya la usan. Si hay alguno, no se elimina.
  final int clientes;

  String get buscable => nombre.toLowerCase();

  factory Ruta.desdeJson(Map<String, dynamic> json) => Ruta(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
    clientes: json['clientes'] as int? ?? 0,
  );
}
