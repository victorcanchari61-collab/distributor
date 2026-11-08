import '../../../compartido/fechas.dart';
import '../../crm/datos/crm.dart' show EstadoCaida;

/// Lo que devuelve y lo que acepta `GET /api/dashboard/sin-ventas/analisis`,
/// la pantalla "Productos sin ventas": lo que vendió cada producto en el tramo
/// frente al mes (o el año) anterior y en qué estado queda.

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

Map<String, dynamic> _mapa(Object? v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};

List<Map<String, dynamic>> _lista(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map<String, dynamic>) e,
      ]
    : const [];

// ----------------------------------------------------------------- Opciones

/// Contra qué se compara el tramo.
enum CompararSinVentas {
  mes('mes', 'Mes anterior', 'el mes anterior'),
  anio('anio', 'Año anterior', 'el año anterior');

  const CompararSinVentas(this.clave, this.etiqueta, this.referencia);

  final String clave;
  final String etiqueta;

  /// "frente a el mes anterior" se lee mal: aquí va ya con su artículo.
  final String referencia;

  static CompararSinVentas desdeClave(String? clave) =>
      clave == 'anio' ? anio : mes;
}

/// Qué se suma: plata o cantidad de unidades.
enum MedidaSinVentas {
  soles('soles', 'Soles'),
  unidades('unidades', 'Unidades');

  const MedidaSinVentas(this.clave, this.etiqueta);

  final String clave;
  final String etiqueta;

  static MedidaSinVentas desdeClave(String? clave) =>
      clave == 'unidades' ? unidades : soles;
}

/// Con qué se decide el estado: lo que cayó la venta o los días sin vender.
enum CriterioSinVentas {
  variacion('variacion', 'Variación de ventas'),
  dias('dias', 'Días sin venta');

  const CriterioSinVentas(this.clave, this.etiqueta);

  final String clave;
  final String etiqueta;

  static CriterioSinVentas desdeClave(String? clave) =>
      clave == 'dias' ? dias : variacion;
}

/// Lo que cubre cada estado según el criterio. Los colores y nombres son los de
/// Clientes con caída ([EstadoCaida]); solo cambia el rango.
String rangoDeEstado(
  EstadoCaida estado,
  CriterioSinVentas criterio,
  CompararSinVentas comparar,
) {
  if (criterio == CriterioSinVentas.dias) {
    return switch (estado) {
      EstadoCaida.critico => '61 días o más',
      EstadoCaida.riesgo => '31 - 60 días',
      EstadoCaida.seguimiento => '16 - 30 días',
      EstadoCaida.normal => '0 - 15 días',
      EstadoCaida.sinBase => 'Nunca vendidos',
    };
  }
  return estado == EstadoCaida.sinBase
      ? 'Sin ventas ${comparar == CompararSinVentas.anio ? 'el año' : 'el mes'} anterior'
      : estado.rango;
}

/// Los estados que cuentan como "en caída": lo que ya se enfrió.
const estadosEnCaida = [
  EstadoCaida.critico,
  EstadoCaida.riesgo,
  EstadoCaida.seguimiento,
];

// ---------------------------------------------------------------- Consulta

/// Lo que el panel de filtros decide que se pida al servidor.
class ConsultaSinVentas {
  const ConsultaSinVentas({
    required this.desde,
    required this.hasta,
    this.comparar = CompararSinVentas.mes,
    this.medida = MedidaSinVentas.soles,
    this.criterio = CriterioSinVentas.variacion,
    this.almacenId,
    this.categoriaId,
    this.marcaId,
    this.incluirSinStock = false,
  });

  /// Del 1 del mes en curso a hoy: de ahí se mide si nadie elige fechas.
  factory ConsultaSinVentas.inicial([DateTime? hoy]) {
    final h = hoy ?? DateTime.now();
    return ConsultaSinVentas(
      desde: DateTime(h.year, h.month, 1),
      hasta: DateTime(h.year, h.month, h.day),
    );
  }

  final DateTime desde;
  final DateTime hasta;
  final CompararSinVentas comparar;
  final MedidaSinVentas medida;
  final CriterioSinVentas criterio;
  final int? almacenId;
  final int? categoriaId;
  final int? marcaId;
  final bool incluirSinStock;

  ConsultaSinVentas copiar({
    DateTime? desde,
    DateTime? hasta,
    CompararSinVentas? comparar,
    MedidaSinVentas? medida,
    CriterioSinVentas? criterio,
    bool? incluirSinStock,
    int? Function()? almacenId,
    int? Function()? categoriaId,
    int? Function()? marcaId,
  }) => ConsultaSinVentas(
    desde: desde ?? this.desde,
    hasta: hasta ?? this.hasta,
    comparar: comparar ?? this.comparar,
    medida: medida ?? this.medida,
    criterio: criterio ?? this.criterio,
    almacenId: almacenId != null ? almacenId() : this.almacenId,
    categoriaId: categoriaId != null ? categoriaId() : this.categoriaId,
    marcaId: marcaId != null ? marcaId() : this.marcaId,
    incluirSinStock: incluirSinStock ?? this.incluirSinStock,
  );

  /// La query tal como la pide el servidor: solo lo que trae valor.
  String get query {
    final partes = <String, String>{
      'desde': diaIso(desde),
      'hasta': diaIso(hasta),
      'comparar': comparar.clave,
      'medida': medida.clave,
      'criterio': criterio.clave,
      'incluirSinStock': '$incluirSinStock',
      if (almacenId != null) 'almacenId': '$almacenId',
      if (categoriaId != null) 'categoriaId': '$categoriaId',
      if (marcaId != null) 'marcaId': '$marcaId',
    };
    return '?${partes.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
  }

  /// Cuántos filtros del servidor se apartan de [base] (lo de siempre).
  int activosFrente(ConsultaSinVentas base) {
    var n = 0;
    if (!mismoDia(desde, base.desde) || !mismoDia(hasta, base.hasta)) n++;
    if (comparar != base.comparar) n++;
    if (medida != base.medida) n++;
    if (criterio != base.criterio) n++;
    if (almacenId != base.almacenId) n++;
    if (categoriaId != base.categoriaId) n++;
    if (marcaId != base.marcaId) n++;
    if (incluirSinStock != base.incluirSinStock) n++;
    return n;
  }

  @override
  bool operator ==(Object other) =>
      other is ConsultaSinVentas &&
      mismoDia(other.desde, desde) &&
      mismoDia(other.hasta, hasta) &&
      other.comparar == comparar &&
      other.medida == medida &&
      other.criterio == criterio &&
      other.almacenId == almacenId &&
      other.categoriaId == categoriaId &&
      other.marcaId == marcaId &&
      other.incluirSinStock == incluirSinStock;

  @override
  int get hashCode => Object.hash(
    diaIso(desde),
    diaIso(hasta),
    comparar,
    medida,
    criterio,
    almacenId,
    categoriaId,
    marcaId,
    incluirSinStock,
  );
}

// -------------------------------------------------------------- Respuesta

class PeriodoSinVentas {
  const PeriodoSinVentas({
    required this.desde,
    required this.hasta,
    required this.anteriorDesde,
    required this.anteriorHasta,
  });

  final DateTime? desde;
  final DateTime? hasta;
  final DateTime? anteriorDesde;
  final DateTime? anteriorHasta;

  factory PeriodoSinVentas.desdeJson(Map<String, dynamic> j) =>
      PeriodoSinVentas(
        desde: fechaDeJsonOpcional(j['desde']),
        hasta: fechaDeJsonOpcional(j['hasta']),
        anteriorDesde: fechaDeJsonOpcional(j['anteriorDesde']),
        anteriorHasta: fechaDeJsonOpcional(j['anteriorHasta']),
      );
}

/// Un producto con lo que vendió en el tramo, lo que vendía antes y su estado.
class ProductoAnalisis {
  const ProductoAnalisis({
    required this.productoId,
    required this.codigo,
    required this.producto,
    this.foto,
    this.marca,
    this.categoriaId,
    this.categoria = '',
    this.unidadBase = '',
    this.ultimaVenta,
    this.nuncaVendido = false,
    this.diasSinVenta = 0,
    this.stock = 0,
    this.costoStock = 0,
    this.ultimaCompra,
    this.anterior = 0,
    this.actual = 0,
    this.variacion = 0,
    this.caidaPct,
    this.perdida = 0,
    this.estado = EstadoCaida.sinBase,
  });

  final int productoId;
  final String codigo;
  final String producto;
  final String? foto;
  final String? marca;
  final int? categoriaId;
  final String categoria;
  final String unidadBase;

  /// Null: nunca se vendió.
  final DateTime? ultimaVenta;
  final bool nuncaVendido;
  final int diasSinVenta;
  final double stock;
  final double costoStock;
  final DateTime? ultimaCompra;
  final double anterior;
  final double actual;
  final double variacion;

  /// Positiva si vendió menos. Null: el tramo anterior no vendió, no hay con
  /// qué comparar.
  final double? caidaPct;
  final double perdida;
  final EstadoCaida estado;

  /// Lo que busca el buscador: producto, código, marca y categoría.
  String get buscable =>
      '$producto $codigo ${marca ?? ''} $categoria'.toLowerCase();

  factory ProductoAnalisis.desdeJson(Map<String, dynamic> j) =>
      ProductoAnalisis(
        productoId: _i(j['productoId']),
        codigo: j['codigo'] as String? ?? '',
        producto: j['producto'] as String? ?? '',
        foto: j['foto'] as String?,
        marca: j['marca'] as String?,
        categoriaId: (j['categoriaId'] as num?)?.toInt(),
        categoria: j['categoria'] as String? ?? '',
        unidadBase: j['unidadBase'] as String? ?? '',
        ultimaVenta: fechaDeJsonOpcional(j['ultimaVenta']),
        nuncaVendido: j['nuncaVendido'] as bool? ?? false,
        diasSinVenta: _i(j['diasSinVenta']),
        stock: _d(j['stock']),
        costoStock: _d(j['costoStock']),
        ultimaCompra: fechaDeJsonOpcional(j['ultimaCompra']),
        anterior: _d(j['anterior']),
        actual: _d(j['actual']),
        variacion: _d(j['variacion']),
        caidaPct: (j['caidaPct'] as num?)?.toDouble(),
        perdida: _d(j['perdida']),
        estado: EstadoCaida.desdeClave(j['estado'] as String?),
      );
}

class EstadoAnalisis {
  const EstadoAnalisis({
    required this.estado,
    this.productos = 0,
    this.costoStock = 0,
    this.perdida = 0,
  });

  final EstadoCaida estado;
  final int productos;
  final double costoStock;
  final double perdida;

  factory EstadoAnalisis.desdeJson(Map<String, dynamic> j) => EstadoAnalisis(
    estado: EstadoCaida.desdeClave(j['estado'] as String?),
    productos: _i(j['productos']),
    costoStock: _d(j['costoStock']),
    perdida: _d(j['perdida']),
  );
}

class CategoriaAnalisis {
  const CategoriaAnalisis({
    required this.categoria,
    this.anterior = 0,
    this.actual = 0,
    this.variacion = 0,
    this.caidaPct,
  });

  final String categoria;
  final double anterior;
  final double actual;
  final double variacion;
  final double? caidaPct;

  factory CategoriaAnalisis.desdeJson(Map<String, dynamic> j) =>
      CategoriaAnalisis(
        categoria: j['categoria'] as String? ?? '',
        anterior: _d(j['anterior']),
        actual: _d(j['actual']),
        variacion: _d(j['variacion']),
        caidaPct: (j['caidaPct'] as num?)?.toDouble(),
      );
}

class PuntoEvolucion {
  const PuntoEvolucion({
    required this.etiqueta,
    this.anterior = 0,
    this.actual = 0,
  });

  /// AAAA-MM-DD (un día) o AAAA-MM (un mes) del tramo actual.
  final String etiqueta;
  final double anterior;
  final double actual;

  factory PuntoEvolucion.desdeJson(Map<String, dynamic> j) => PuntoEvolucion(
    etiqueta: j['etiqueta'] as String? ?? '',
    anterior: _d(j['anterior']),
    actual: _d(j['actual']),
  );
}

class SerieEvolucion {
  const SerieEvolucion({
    required this.clave,
    this.anterior = 0,
    this.actual = 0,
    this.puntos = const [],
  });

  /// "TODOS" (los que cayeron) o la clave de un estado.
  final String clave;
  final double anterior;
  final double actual;
  final List<PuntoEvolucion> puntos;

  /// Sin una sola venta en ningún punto no hay línea que dibujar.
  bool get sinVentas => puntos.every((p) => p.anterior == 0 && p.actual == 0);

  factory SerieEvolucion.desdeJson(Map<String, dynamic> j) => SerieEvolucion(
    clave: j['clave'] as String? ?? '',
    anterior: _d(j['anterior']),
    actual: _d(j['actual']),
    puntos: [for (final p in _lista(j['puntos'])) PuntoEvolucion.desdeJson(p)],
  );
}

class ResumenAnalisis {
  const ResumenAnalisis({
    this.totalProductos = 0,
    this.enCaida = 0,
    this.conStock = 0,
    this.unidadesInmovilizadas = 0,
    this.stockInmovilizado = 0,
    this.ventaPerdida = 0,
  });

  final int totalProductos;
  final int enCaida;
  final int conStock;
  final double unidadesInmovilizadas;
  final double stockInmovilizado;
  final double ventaPerdida;

  factory ResumenAnalisis.desdeJson(Map<String, dynamic> j) => ResumenAnalisis(
    totalProductos: _i(j['totalProductos']),
    enCaida: _i(j['enCaida']),
    conStock: _i(j['conStock']),
    unidadesInmovilizadas: _d(j['unidadesInmovilizadas']),
    stockInmovilizado: _d(j['stockInmovilizado']),
    ventaPerdida: _d(j['ventaPerdida']),
  );
}

/// El análisis completo de "Productos sin ventas".
class AnalisisSinVentas {
  const AnalisisSinVentas({
    required this.periodo,
    this.comparar = CompararSinVentas.mes,
    this.medida = MedidaSinVentas.soles,
    this.criterio = CriterioSinVentas.variacion,
    this.granularidad = 'dia',
    this.corte,
    this.resumen = const ResumenAnalisis(),
    this.estados = const [],
    this.porCategoria = const [],
    this.evolucion = const [],
    this.items = const [],
  });

  final PeriodoSinVentas periodo;
  final CompararSinVentas comparar;
  final MedidaSinVentas medida;
  final CriterioSinVentas criterio;

  /// 'dia' o 'mes': cada cuánto es un punto de la evolución.
  final String granularidad;
  final DateTime? corte;
  final ResumenAnalisis resumen;
  final List<EstadoAnalisis> estados;
  final List<CategoriaAnalisis> porCategoria;
  final List<SerieEvolucion> evolucion;
  final List<ProductoAnalisis> items;

  bool get porDia => granularidad != 'mes';

  /// Los productos de todos los estados: lo que mide la dona.
  int get totalEnEstados => estados.fold(0, (s, e) => s + e.productos);

  EstadoAnalisis? deEstado(EstadoCaida e) =>
      estados.where((r) => r.estado == e).firstOrNull;

  SerieEvolucion? serie(String clave) =>
      evolucion.where((s) => s.clave == clave).firstOrNull;

  /// Lo que dejó de vender el grupo de la serie: los que cayeron (todos menos
  /// "sin comparación") o los de un solo estado.
  double perdidaDeSerie(String clave) => clave == 'TODOS'
      ? estados
            .where((e) => e.estado != EstadoCaida.sinBase)
            .fold(0.0, (s, e) => s + e.perdida)
      : estados.where((e) => e.estado.clave == clave).firstOrNull?.perdida ?? 0;

  factory AnalisisSinVentas.desdeJson(
    Map<String, dynamic> j,
  ) => AnalisisSinVentas(
    periodo: PeriodoSinVentas.desdeJson(_mapa(j['periodo'])),
    comparar: CompararSinVentas.desdeClave(j['comparar'] as String?),
    medida: MedidaSinVentas.desdeClave(j['medida'] as String?),
    criterio: CriterioSinVentas.desdeClave(j['criterio'] as String?),
    granularidad: j['granularidad'] as String? ?? 'dia',
    corte: fechaDeJsonOpcional(j['corte']),
    resumen: ResumenAnalisis.desdeJson(_mapa(j['resumen'])),
    estados: [
      for (final e in _lista(j['estados'])) EstadoAnalisis.desdeJson(e),
    ],
    porCategoria: [
      for (final c in _lista(j['porCategoria'])) CategoriaAnalisis.desdeJson(c),
    ],
    evolucion: [
      for (final s in _lista(j['evolucion'])) SerieEvolucion.desdeJson(s),
    ],
    items: [for (final p in _lista(j['items'])) ProductoAnalisis.desdeJson(p)],
  );
}

// ------------------------------------------------------ Etiquetas de la línea

const _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'set', 'oct', 'nov', 'dic', //
];

/// La etiqueta del eje de un punto: "5/11" si es un día, "nov" si es un mes.
String etiquetaEjeEvolucion(String etiqueta, {required bool porDia}) {
  final partes = etiqueta.split('-');
  if (partes.length < 2) return etiqueta;
  final mes = int.tryParse(partes[1]) ?? 0;
  if (porDia) {
    final dia = partes.length > 2 ? int.tryParse(partes[2]) : null;
    return dia == null ? etiqueta : '$dia/$mes';
  }
  return mes >= 1 && mes <= 12 ? _mesesCortos[mes - 1] : etiqueta;
}

/// La etiqueta del globo: "05/11/2026" si es un día, "nov 2026" si es un mes.
String etiquetaLargaEvolucion(String etiqueta, {required bool porDia}) {
  final partes = etiqueta.split('-');
  if (partes.length < 2) return etiqueta;
  final mes = int.tryParse(partes[1]) ?? 0;
  if (porDia && partes.length > 2) {
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }
  return mes >= 1 && mes <= 12
      ? '${_mesesCortos[mes - 1]} ${partes[0]}'
      : etiqueta;
}

// --------------------------------------------------- Filtros sobre lo traído

/// Cuántos días lleva un producto sin moverse: cada fila ya trae los suyos, así
/// que se acota aquí y no en el servidor.
enum MovimientoSinVentas {
  dias15('15 días o más', 15),
  dias30('30 días o más', 30),
  dias60('60 días o más', 60),
  dias90('90 días o más', 90),
  nunca('Nunca vendidos', null);

  const MovimientoSinVentas(this.etiqueta, this.dias);

  final String etiqueta;

  /// Null: los que nunca se vendieron.
  final int? dias;

  bool incluye(ProductoAnalisis p) =>
      dias == null ? p.nuncaVendido : p.diasSinVenta >= dias!;
}

enum StockSinVentas {
  con('Con stock'),
  sin('Sin stock');

  const StockSinVentas(this.etiqueta);

  final String etiqueta;
}

/// Lo que el panel acota sobre lo que ya llegó.
class FiltrosLocalesSinVentas {
  const FiltrosLocalesSinVentas({
    this.movimiento,
    this.stock,
    this.stockDesde,
    this.stockHasta,
  });

  final MovimientoSinVentas? movimiento;
  final StockSinVentas? stock;
  final double? stockDesde;
  final double? stockHasta;

  int get activos =>
      (movimiento != null ? 1 : 0) +
      (stock != null ? 1 : 0) +
      (stockDesde != null ? 1 : 0) +
      (stockHasta != null ? 1 : 0);

  bool incluye(ProductoAnalisis p) {
    if (stock == StockSinVentas.con && p.stock <= 0) return false;
    if (stock == StockSinVentas.sin && p.stock > 0) return false;
    if (stockDesde != null && p.stock < stockDesde!) return false;
    if (stockHasta != null && p.stock > stockHasta!) return false;
    if (movimiento != null && !movimiento!.incluye(p)) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is FiltrosLocalesSinVentas &&
      other.movimiento == movimiento &&
      other.stock == stock &&
      other.stockDesde == stockDesde &&
      other.stockHasta == stockHasta;

  @override
  int get hashCode => Object.hash(movimiento, stock, stockDesde, stockHasta);
}

/// La tarjeta de "Productos sin ventas": crítico, en riesgo y en seguimiento.
const claveEnCaida = 'CAIDA';

/// Lo que se ve en la lista: la tarjeta de estado elegida, el buscador y los
/// filtros de movimiento y stock. Las tarjetas, la dona y los gráficos miden
/// todos los productos; solo la lista se acota.
///
/// [estado] es la clave de un estado, [claveEnCaida] o null (todos).
List<ProductoAnalisis> filtrarProductos(
  List<ProductoAnalisis> todos, {
  String? estado,
  String busqueda = '',
  FiltrosLocalesSinVentas locales = const FiltrosLocalesSinVentas(),
}) {
  final texto = busqueda.trim().toLowerCase();

  bool delEstado(ProductoAnalisis p) {
    if (estado == null) return true;
    if (estado == claveEnCaida) return estadosEnCaida.contains(p.estado);
    return p.estado.clave == estado;
  }

  return [
    for (final p in todos)
      if (delEstado(p) &&
          (texto.isEmpty || p.buscable.contains(texto)) &&
          locales.incluye(p))
        p,
  ];
}

// ------------------------------------------------------------- Catálogos

/// Una opción de un filtro: almacén, categoría o marca.
class OpcionCatalogo {
  const OpcionCatalogo(this.id, this.nombre);

  final int id;
  final String nombre;

  /// Los inactivos no se ofrecen. Lo que no trae `activo` se toma por activo.
  static List<OpcionCatalogo> desdeLista(Object? json) => [
    for (final e in _lista(json))
      if (e['id'] is num && (e['activo'] as bool? ?? true))
        OpcionCatalogo((e['id'] as num).toInt(), e['nombre'] as String? ?? ''),
  ];
}
