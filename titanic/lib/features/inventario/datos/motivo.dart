class TipoMotivo {
  const TipoMotivo._();
  static const entrada = 'ENTRADA';
  static const salida = 'SALIDA';
}

/// La razon de un ajuste: por que entro o salio mercaderia fuera del flujo
/// normal de compras y ventas.
class Motivo {
  const Motivo({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.tipo,
    required this.delSistema,
    required this.pideCosto,
    required this.activo,
    required this.movimientos,
  });

  final int id;
  final String codigo;
  final String nombre;

  /// ENTRADA o SALIDA.
  final String tipo;

  /// Del sistema: no se elige a mano, no se edita ni se elimina.
  final bool delSistema;

  /// Si al usarlo hay que declarar el costo.
  final bool pideCosto;

  final bool activo;

  /// Cuantos movimientos lo usan.
  final int movimientos;

  bool get esEntrada => tipo == TipoMotivo.entrada;

  String get buscable => '$codigo $nombre'.toLowerCase();

  factory Motivo.desdeJson(Map<String, dynamic> json) => Motivo(
    id: json['id'] as int,
    codigo: json['codigo'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    tipo: json['tipo'] as String? ?? TipoMotivo.entrada,
    delSistema: json['delSistema'] as bool? ?? false,
    pideCosto: json['pideCosto'] as bool? ?? false,
    activo: json['activo'] as bool? ?? true,
    movimientos: json['movimientos'] as int? ?? 0,
  );
}
