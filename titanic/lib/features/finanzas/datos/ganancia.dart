import '../../../compartido/fechas.dart';

// Modelos de "Mis ganancias": calcan los DTOs del backend
// (GananciaResponses.cs).
//
// La base es el producto: cuánto se ganó con cada uno, que es lo vendido menos
// lo que costó la mercadería que salió (el costo real de cada salida, la más
// antigua primero). Fecha, vendedor, venta, categoría y marca son filtros que
// recortan qué ventas entran en la suma.

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

List<String> _textos(dynamic v) => [
  for (final e in (v as List?) ?? const []) e.toString(),
];

/// Cuánto se ganó con un producto en el rango pedido.
class GananciaProducto {
  const GananciaProducto({
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.categoria,
    required this.marca,
    required this.cantidad,
    required this.unidadBase,
    required this.ventas,
    required this.notas,
    required this.vendedores,
    required this.ultimaVenta,
    required this.importe,
    required this.costo,
    required this.ganancia,
    required this.sinCosto,
    this.margen,
  });

  final int productoId;
  final String codigo;
  final String producto;
  final String categoria;
  final String marca;

  /// Cuánto se vendió, en unidad base.
  final double cantidad;
  final String unidadBase;

  /// En cuántas ventas salió.
  final int ventas;

  /// Los números de esas ventas: NV-0004.
  final List<String> notas;
  final List<String> vendedores;

  /// Un día suelto, sin hora: se muestra tal cual, no se convierte de UTC.
  final DateTime ultimaVenta;

  final double importe;
  final double costo;
  final double ganancia;

  /// En %. Null si no hubo importe.
  final double? margen;

  /// Parte de esa mercadería entró sin declarar su costo: en esas líneas la
  /// ganancia sale igual al precio y el total queda inflado.
  final bool sinCosto;

  bool get enPerdida => ganancia < 0;

  factory GananciaProducto.desdeJson(Map<String, dynamic> json) =>
      GananciaProducto(
        productoId: json['productoId'] as int,
        codigo: json['codigo'] as String? ?? '',
        producto: json['producto'] as String? ?? '',
        categoria: json['categoria'] as String? ?? '',
        marca: json['marca'] as String? ?? '',
        cantidad: _num(json['cantidad']),
        unidadBase: json['unidadBase'] as String? ?? '',
        ventas: json['ventas'] as int? ?? 0,
        notas: _textos(json['notas']),
        vendedores: _textos(json['vendedores']),
        ultimaVenta: fechaDeJson(json['ultimaVenta'] as String),
        importe: _num(json['importe']),
        costo: _num(json['costo']),
        ganancia: _num(json['ganancia']),
        margen: (json['margen'] as num?)?.toDouble(),
        sinCosto: json['sinCosto'] as bool? ?? false,
      );
}

/// Los totales de TODO lo filtrado, no solo de la página que se ve.
class GananciaResumen {
  const GananciaResumen({
    required this.desde,
    required this.hasta,
    required this.soloPropio,
    required this.ventas,
    required this.productos,
    required this.importe,
    required this.costo,
    required this.ganancia,
    required this.lineasSinCosto,
    this.margen,
  });

  /// El primer y el último día contados. Sin fechas en la consulta, el servidor
  /// cuenta lo que va del mes.
  final DateTime desde;
  final DateTime hasta;

  /// Si lo que se ve es solo lo propio o todo el negocio.
  final bool soloPropio;

  final int ventas;
  final int productos;
  final double importe;
  final double costo;
  final double ganancia;
  final double? margen;

  /// Líneas vendidas sin costo: la mercadería entró sin declararlo.
  final int lineasSinCosto;

  factory GananciaResumen.desdeJson(Map<String, dynamic> json) =>
      GananciaResumen(
        desde: fechaDeJson(json['desde'] as String),
        hasta: fechaDeJson(json['hasta'] as String),
        soloPropio: json['soloPropio'] as bool? ?? false,
        ventas: json['ventas'] as int? ?? 0,
        productos: json['productos'] as int? ?? 0,
        importe: _num(json['importe']),
        costo: _num(json['costo']),
        ganancia: _num(json['ganancia']),
        margen: (json['margen'] as num?)?.toDouble(),
        lineasSinCosto: json['lineasSinCosto'] as int? ?? 0,
      );
}

/// Lo que hay para elegir en los filtros, dentro del rango de fechas.
///
/// Se arma antes de filtrar: elegir un vendedor no encoge las demás listas, así
/// que siempre hay cómo cambiar de opinión.
class GananciaOpciones {
  const GananciaOpciones({
    this.vendedores = const [],
    this.categorias = const [],
    this.marcas = const [],
    this.productos = const [],
    this.ventas = const [],
  });

  final List<String> vendedores;
  final List<String> categorias;
  final List<String> marcas;

  /// Los productos que se vendieron en el rango.
  final List<String> productos;

  /// Los números de las ventas del rango: NV-0004.
  final List<String> ventas;

  factory GananciaOpciones.desdeJson(Map<String, dynamic> json) =>
      GananciaOpciones(
        vendedores: _textos(json['vendedores']),
        categorias: _textos(json['categorias']),
        marcas: _textos(json['marcas']),
        productos: _textos(json['productos']),
        ventas: _textos(json['ventas']),
      );
}

/// Una página de la respuesta: los productos de esa página, el total de
/// productos con esos filtros, los totales y las opciones de los filtros.
class GananciaPagina {
  const GananciaPagina({
    required this.items,
    required this.total,
    required this.resumen,
    required this.opciones,
  });

  final List<GananciaProducto> items;

  /// Cuántos productos hay con esos filtros, no solo en esta página.
  final int total;
  final GananciaResumen resumen;
  final GananciaOpciones opciones;

  factory GananciaPagina.desdeJson(Map<String, dynamic> json) => GananciaPagina(
    items: [
      for (final e in (json['items'] as List?) ?? const [])
        GananciaProducto.desdeJson(e as Map<String, dynamic>),
    ],
    total: json['total'] as int? ?? 0,
    resumen: GananciaResumen.desdeJson(json['resumen'] as Map<String, dynamic>),
    opciones: GananciaOpciones.desdeJson(
      json['opciones'] as Map<String, dynamic>? ?? const {},
    ),
  );
}
