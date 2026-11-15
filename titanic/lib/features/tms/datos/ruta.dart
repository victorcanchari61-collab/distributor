/// Ruta de reparto a la que pertenece un cliente.
class Ruta {
  const Ruta({
    required this.id,
    required this.nombre,
    required this.activo,
    this.clientes = 0,
    this.vendedores = const [],
    this.mercados = const [],
    this.salidas = const [],
    this.ventasMes = 0,
    this.clientesConCompraMes = 0,
    this.porCobrar = 0,
    this.clientesConDeuda = 0,
  });

  final int id;
  final String nombre;
  final bool activo;

  /// Cuántos clientes ya la usan. Si hay alguno, no se elimina.
  final int clientes;

  /// Quiénes la tienen a cargo (puede ser más de uno). Se asigna en Usuarios.
  final List<String> vendedores;

  /// Los mercados donde están sus clientes activos, por nombre.
  final List<String> mercados;

  /// Qué días sale y en qué camión, según los recorridos de Flota.
  final List<SalidaRuta> salidas;

  /// Lo vendido este mes a sus clientes.
  final double ventasMes;

  /// Cuántos de sus clientes compraron este mes.
  final int clientesConCompraMes;

  /// Lo que deben sus clientes en ventas al crédito.
  final double porCobrar;

  /// Cuántos de sus clientes deben algo.
  final int clientesConDeuda;

  String get buscable => nombre.toLowerCase();

  /// Los días en que sale, en orden de semana y sin repetir: dos camiones el
  /// mismo lunes siguen siendo un lunes.
  List<String> get dias => [
    for (final d in SalidaRuta.dias)
      if (salidas.any((s) => s.dia == d)) d,
  ];

  /// Las placas de los camiones que la llevan, sin repetir.
  List<String> get placas => {for (final s in salidas) s.placa}.toList();

  factory Ruta.desdeJson(Map<String, dynamic> json) => Ruta(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
    clientes: json['clientes'] as int? ?? 0,
    vendedores: [
      for (final v in (json['vendedores'] as List? ?? const [])) v as String,
    ],
    // Lo que sigue llega desde que el API cuenta ventas y deuda por ruta: con
    // un backend anterior falta y queda vacío o en cero.
    mercados: [
      for (final m in (json['mercados'] as List? ?? const [])) m as String,
    ],
    salidas: [
      for (final s in (json['salidas'] as List? ?? const []))
        SalidaRuta.desdeJson(s as Map<String, dynamic>),
    ],
    ventasMes: (json['ventasMes'] as num?)?.toDouble() ?? 0,
    clientesConCompraMes: json['clientesConCompraMes'] as int? ?? 0,
    porCobrar: (json['porCobrar'] as num?)?.toDouble() ?? 0,
    clientesConDeuda: json['clientesConDeuda'] as int? ?? 0,
  );
}

/// Un día en que sale la ruta y el camión que la lleva.
class SalidaRuta {
  const SalidaRuta({required this.dia, required this.placa});

  /// LUNES … DOMINGO.
  final String dia;
  final String placa;

  /// Los días como los manda el API, en orden de semana.
  static const dias = [
    'LUNES',
    'MARTES',
    'MIERCOLES',
    'JUEVES',
    'VIERNES',
    'SABADO',
    'DOMINGO',
  ];

  /// "Lun", "Mar"…, como la columna Días del panel web.
  static const corto = {
    'LUNES': 'Lun',
    'MARTES': 'Mar',
    'MIERCOLES': 'Mié',
    'JUEVES': 'Jue',
    'VIERNES': 'Vie',
    'SABADO': 'Sáb',
    'DOMINGO': 'Dom',
  };

  factory SalidaRuta.desdeJson(Map<String, dynamic> json) => SalidaRuta(
    dia: json['dia'] as String? ?? '',
    placa: json['placa'] as String? ?? '',
  );
}
