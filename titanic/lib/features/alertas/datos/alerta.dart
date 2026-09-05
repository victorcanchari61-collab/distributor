/// Algo que conviene que alguien mire: stock bajo, un lote por vencer, una
/// compra sin recibir hace mucho... Se calcula en el backend al pedirla, no
/// se guarda en ningun lado, asi que nunca hay que marcarla como leida.
class Alerta {
  const Alerta({
    required this.id,
    required this.tipo,
    required this.severidad,
    required this.titulo,
    required this.detalle,
    this.ruta,
    this.fecha,
  });

  final String id;
  final String tipo;

  /// CRITICA, ADVERTENCIA o INFO (una buena noticia, no algo por corregir).
  final String severidad;

  final String titulo;
  final String detalle;

  /// Id de vista del menu ("inv.stock"), para navegar al tocarla.
  final String? ruta;
  final DateTime? fecha;

  factory Alerta.desdeJson(Map<String, dynamic> json) => Alerta(
    id: json['id'] as String? ?? '',
    tipo: json['tipo'] as String? ?? '',
    severidad: json['severidad'] as String? ?? 'ADVERTENCIA',
    titulo: json['titulo'] as String? ?? '',
    detalle: json['detalle'] as String? ?? '',
    ruta: json['ruta'] as String?,
    fecha: json['fecha'] == null ? null : DateTime.tryParse(json['fecha'] as String),
  );
}

class SeveridadAlerta {
  const SeveridadAlerta._();
  static const critica = 'CRITICA';
  static const advertencia = 'ADVERTENCIA';
  static const info = 'INFO';
}

class TipoAlerta {
  const TipoAlerta._();
  static const stockBajo = 'STOCK_BAJO';
  static const lotePorVencer = 'LOTE_POR_VENCER';
  static const compraPendiente = 'COMPRA_PENDIENTE';
  static const creditoPendiente = 'CREDITO_PENDIENTE';
  static const reservaVencida = 'RESERVA_VENCIDA';
  static const stockRepuesto = 'STOCK_REPUESTO';
}
