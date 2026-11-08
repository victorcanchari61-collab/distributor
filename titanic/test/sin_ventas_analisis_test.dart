import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/core/red/cliente_api.dart';
import 'package:titanic/core/red/excepciones.dart';
import 'package:titanic/core/red/tiempo_real_provider.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';
import 'package:titanic/features/crm/datos/crm.dart';
import 'package:titanic/features/dashboard/datos/sin_ventas_analisis_api.dart';
import 'package:titanic/features/dashboard/datos/sin_ventas_analisis_modelos.dart';
import 'package:titanic/features/dashboard/estado/sin_ventas_analisis_controlador.dart';
import 'package:titanic/features/dashboard/vistas/sin_ventas_pagina.dart';
import 'package:titanic/features/dashboard/widgets/grafico_barras_h.dart';
import 'package:titanic/features/dashboard/widgets/grafico_dona.dart';
import 'package:titanic/features/dashboard/widgets/grafico_linea.dart';

class _AlmacenConSesion extends SesionAlmacen {
  const _AlmacenConSesion();

  @override
  Future<String?> token() async => 'token';

  @override
  Future<Map<String, dynamic>?> usuario() async => {
    'id': 1,
    'nombre': 'Admin',
    'email': 'admin@distributor.com',
    'rolId': 1,
    'rol': 'Administrador',
    'activo': true,
  };

  @override
  Future<bool> recordar() async => true;
}

// --------------------------------------------------------- Datos de ejemplo

Map<String, dynamic> _item(
  int id,
  String nombre,
  String estado, {
  String? ultimaVenta,
  bool nunca = false,
  int dias = 0,
  double stock = 0,
  double costo = 0,
  double anterior = 0,
  double actual = 0,
  double? caida,
  double perdida = 0,
}) => {
  'productoId': id,
  'codigo': 'P000$id',
  'producto': nombre,
  'foto': null,
  'marca': 'Marca $id',
  'categoriaId': id,
  'categoria': 'Categoría $id',
  'unidadBase': 'UND',
  'ultimaVenta': ultimaVenta,
  'nuncaVendido': nunca,
  'diasSinVenta': dias,
  'stock': stock,
  'costoStock': costo,
  'ultimaCompra': '2026-08-20T00:00:00',
  'anterior': anterior,
  'actual': actual,
  'variacion': actual - anterior,
  'caidaPct': caida,
  'perdida': perdida,
  'estado': estado,
};

Map<String, dynamic> _respuesta() => {
  'periodo': {
    'desde': '2026-11-01T00:00:00',
    'hasta': '2026-11-08T00:00:00',
    'anteriorDesde': '2026-10-01T00:00:00',
    'anteriorHasta': '2026-10-08T00:00:00',
  },
  'comparar': 'mes',
  'medida': 'soles',
  'criterio': 'variacion',
  'granularidad': 'dia',
  'corte': '2026-11-08T00:00:00',
  'resumen': {
    'totalProductos': 4,
    'enCaida': 2,
    'conStock': 3,
    'unidadesInmovilizadas': 40,
    'stockInmovilizado': 800,
    'ventaPerdida': 1200,
  },
  'estados': [
    {'estado': 'CRITICO', 'productos': 1, 'costoStock': 800, 'perdida': 900},
    {'estado': 'RIESGO', 'productos': 1, 'costoStock': 0, 'perdida': 300},
    {'estado': 'NORMAL', 'productos': 1, 'costoStock': 50, 'perdida': 0},
    {'estado': 'SIN_BASE', 'productos': 1, 'costoStock': 20, 'perdida': 0},
  ],
  'porCategoria': [
    {
      'categoria': 'Aceites',
      'anterior': 1000,
      'actual': 100,
      'variacion': -900,
      'caidaPct': 90,
    },
    {
      'categoria': 'Granos',
      'anterior': 0,
      'actual': 0,
      'variacion': -50,
      'caidaPct': null,
    },
  ],
  'evolucion': [
    {
      'clave': 'TODOS',
      'anterior': 1500,
      'actual': 300,
      'puntos': [
        {'etiqueta': '2026-11-01', 'anterior': 500, 'actual': 100},
        {'etiqueta': '2026-11-02', 'anterior': 500, 'actual': 100},
        {'etiqueta': '2026-11-03', 'anterior': 500, 'actual': 100},
      ],
    },
    {
      'clave': 'CRITICO',
      'anterior': 1000,
      'actual': 100,
      'puntos': [
        {'etiqueta': '2026-11-01', 'anterior': 1000, 'actual': 100},
      ],
    },
  ],
  'items': [
    _item(
      1,
      'ACEITE 1L',
      'CRITICO',
      ultimaVenta: '2026-09-01T00:00:00',
      dias: 68,
      stock: 40,
      costo: 800,
      anterior: 1000,
      actual: 100,
      caida: 90,
      perdida: 900,
    ),
    _item(
      2,
      'ARROZ 5KG',
      'RIESGO',
      ultimaVenta: '2026-10-01T00:00:00',
      dias: 38,
      anterior: 500,
      actual: 200,
      caida: 60,
      perdida: 300,
    ),
    _item(
      3,
      'AZUCAR RUBIA',
      'NORMAL',
      ultimaVenta: '2026-11-05T00:00:00',
      dias: 3,
      stock: 10,
      costo: 50,
      anterior: 100,
      actual: 100,
      caida: 0,
    ),
    _item(
      4,
      'LECHE EVAPORADA',
      'SIN_BASE',
      nunca: true,
      dias: 365,
      stock: 5,
      costo: 20,
    ),
  ],
};

List<ProductoAnalisis> _productos() =>
    AnalisisSinVentas.desdeJson(_respuesta()).items;

/// API de mentira: no toca la red y anota cada consulta.
class _ApiFalsa extends SinVentasAnalisisApi {
  _ApiFalsa({this.falla = false, this.sinPermisoEnCatalogos = false})
    : super(ClienteApi());

  final bool falla;
  final bool sinPermisoEnCatalogos;
  final consultas = <ConsultaSinVentas>[];

  @override
  Future<AnalisisSinVentas> analisis(ConsultaSinVentas consulta) async {
    consultas.add(consulta);
    if (falla) throw const ApiExcepcion('El servidor no responde');
    return AnalisisSinVentas.desdeJson(_respuesta());
  }

  Future<List<OpcionCatalogo>> _catalogo(List<OpcionCatalogo> datos) async {
    if (sinPermisoEnCatalogos) {
      throw const ApiExcepcion(
        'Sin permiso',
        codigo: 403,
        submodulo: 'inv.almacen',
        accion: 'ver',
      );
    }
    return datos;
  }

  @override
  Future<List<OpcionCatalogo>> almacenes() =>
      _catalogo(const [OpcionCatalogo(1, 'Almacén central')]);

  @override
  Future<List<OpcionCatalogo>> categorias() =>
      _catalogo(const [OpcionCatalogo(1, 'Aceites')]);

  @override
  Future<List<OpcionCatalogo>> marcas() =>
      _catalogo(const [OpcionCatalogo(1, 'Primor')]);
}

Future<ProviderContainer> _montar(WidgetTester tester, _ApiFalsa api) async {
  tester.view.physicalSize = const Size(375, 7000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionAlmacenProvider.overrideWithValue(const _AlmacenConSesion()),
        sinVentasAnalisisApiProvider.overrideWithValue(api),
        // Sin conexión viva: los avisos de tiempo real no entran en la prueba.
        cambiosProvider.overrideWith((ref, modulos) => const Stream.empty()),
      ],
      child: MaterialApp(theme: Tema.claro(), home: const SinVentasPagina()),
    ),
  );
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(
    tester.element(find.byType(SinVentasPagina)),
  );
}

void main() {
  // ------------------------------------------------------------------ Modelos

  group('modelos', () {
    test('leen el JSON del análisis completo', () {
      final a = AnalisisSinVentas.desdeJson(_respuesta());

      expect(a.comparar, CompararSinVentas.mes);
      expect(a.medida, MedidaSinVentas.soles);
      expect(a.criterio, CriterioSinVentas.variacion);
      expect(a.porDia, isTrue);
      expect(a.periodo.desde, DateTime(2026, 11, 1));
      expect(a.periodo.anteriorHasta, DateTime(2026, 10, 8));
      expect(a.corte, DateTime(2026, 11, 8));

      expect(a.resumen.totalProductos, 4);
      expect(a.resumen.enCaida, 2);
      expect(a.resumen.ventaPerdida, 1200);
      expect(a.resumen.stockInmovilizado, 800);

      expect(a.estados, hasLength(4));
      expect(a.deEstado(EstadoCaida.critico)!.productos, 1);
      expect(a.deEstado(EstadoCaida.riesgo)!.perdida, 300);
      // Un estado que el servidor no mandó no existe: la tarjeta lo lee como 0.
      expect(a.deEstado(EstadoCaida.seguimiento), isNull);
      expect(a.totalEnEstados, 4);

      expect(a.porCategoria.first.categoria, 'Aceites');
      expect(a.porCategoria.first.caidaPct, 90);
      expect(a.porCategoria.last.caidaPct, isNull);

      final todos = a.serie('TODOS')!;
      expect(todos.puntos, hasLength(3));
      expect(todos.puntos.first.etiqueta, '2026-11-01');
      expect(todos.actual, 300);
      expect(todos.sinVentas, isFalse);
      expect(a.serie('NORMAL'), isNull);
    });

    test('cada producto trae sus fechas, su estado y sus nulos', () {
      final items = _productos();
      expect(items, hasLength(4));

      final aceite = items.first;
      expect(aceite.codigo, 'P0001');
      expect(aceite.producto, 'ACEITE 1L');
      expect(aceite.estado, EstadoCaida.critico);
      expect(aceite.ultimaVenta, DateTime(2026, 9, 1));
      expect(aceite.ultimaCompra, DateTime(2026, 8, 20));
      expect(aceite.nuncaVendido, isFalse);
      expect(aceite.diasSinVenta, 68);
      expect(aceite.stock, 40);
      expect(aceite.variacion, -900);
      expect(aceite.caidaPct, 90);
      expect(aceite.perdida, 900);
      expect(aceite.foto, isNull);

      final leche = items.last;
      expect(leche.estado, EstadoCaida.sinBase);
      expect(leche.nuncaVendido, isTrue);
      expect(leche.ultimaVenta, isNull);
      expect(leche.caidaPct, isNull);
    });

    test('la pérdida de la serie: todos los que cayeron o un estado', () {
      final a = AnalisisSinVentas.desdeJson(_respuesta());
      // Crítico + en riesgo; "sin comparación" no cuenta.
      expect(a.perdidaDeSerie('TODOS'), 1200);
      expect(a.perdidaDeSerie('CRITICO'), 900);
      expect(a.perdidaDeSerie('SEGUIMIENTO'), 0);
    });

    test('un cuerpo vacío o con claves nuevas no revienta', () {
      final vacio = AnalisisSinVentas.desdeJson(const {});
      expect(vacio.items, isEmpty);
      expect(vacio.estados, isEmpty);
      expect(vacio.porDia, isTrue);
      expect(vacio.totalEnEstados, 0);
      expect(vacio.medida, MedidaSinVentas.soles);

      // Un estado desconocido cae en "sin comparación", como en Clientes.
      final raro = ProductoAnalisis.desdeJson({
        'productoId': 9,
        'estado': 'OTRO',
        'diasSinVenta': 2.0,
      });
      expect(raro.estado, EstadoCaida.sinBase);
      expect(raro.diasSinVenta, 2);
    });

    test('las etiquetas de la línea: día o mes', () {
      expect(etiquetaEjeEvolucion('2026-11-05', porDia: true), '5/11');
      expect(etiquetaEjeEvolucion('2026-11', porDia: false), 'nov');
      expect(etiquetaLargaEvolucion('2026-11-05', porDia: true), '05/11/2026');
      expect(etiquetaLargaEvolucion('2026-03', porDia: false), 'mar 2026');
      expect(etiquetaEjeEvolucion('raro', porDia: true), 'raro');
    });

    test('los rangos de cada estado cambian con el criterio', () {
      String rango(EstadoCaida e, CriterioSinVentas c) =>
          rangoDeEstado(e, c, CompararSinVentas.mes);

      expect(rango(EstadoCaida.critico, CriterioSinVentas.variacion), '71 % o más');
      expect(rango(EstadoCaida.riesgo, CriterioSinVentas.variacion), '26 - 70 %');
      expect(rango(EstadoCaida.normal, CriterioSinVentas.variacion), '0 - 10 %');
      expect(
        rango(EstadoCaida.sinBase, CriterioSinVentas.variacion),
        'Sin ventas el mes anterior',
      );
      expect(
        rangoDeEstado(
          EstadoCaida.sinBase,
          CriterioSinVentas.variacion,
          CompararSinVentas.anio,
        ),
        'Sin ventas el año anterior',
      );

      expect(rango(EstadoCaida.critico, CriterioSinVentas.dias), '61 días o más');
      expect(rango(EstadoCaida.riesgo, CriterioSinVentas.dias), '31 - 60 días');
      expect(rango(EstadoCaida.seguimiento, CriterioSinVentas.dias), '16 - 30 días');
      expect(rango(EstadoCaida.normal, CriterioSinVentas.dias), '0 - 15 días');
      expect(rango(EstadoCaida.sinBase, CriterioSinVentas.dias), 'Nunca vendidos');
    });
  });

  // ----------------------------------------------------------------- Consulta

  group('consulta al servidor', () {
    test('por defecto: del 1 del mes a hoy, contra el mes anterior', () {
      final c = ConsultaSinVentas.inicial(DateTime(2026, 11, 8, 15, 30));

      expect(c.desde, DateTime(2026, 11, 1));
      expect(c.hasta, DateTime(2026, 11, 8));
      expect(c.comparar, CompararSinVentas.mes);
      expect(c.medida, MedidaSinVentas.soles);
      expect(c.criterio, CriterioSinVentas.variacion);
      expect(c.incluirSinStock, isFalse);
      expect(
        c.query,
        '?desde=2026-11-01&hasta=2026-11-08&comparar=mes&medida=soles'
        '&criterio=variacion&incluirSinStock=false',
      );
    });

    test('la query lleva solo los filtros puestos', () {
      final c = ConsultaSinVentas.inicial(DateTime(2026, 11, 8)).copiar(
        comparar: CompararSinVentas.anio,
        medida: MedidaSinVentas.unidades,
        criterio: CriterioSinVentas.dias,
        almacenId: () => 3,
        categoriaId: () => 7,
        marcaId: () => 9,
        incluirSinStock: true,
      );

      expect(
        c.query,
        '?desde=2026-11-01&hasta=2026-11-08&comparar=anio&medida=unidades'
        '&criterio=dias&incluirSinStock=true&almacenId=3&categoriaId=7&marcaId=9',
      );

      // Quitar una sucursal la saca de la query.
      final sin = c.copiar(almacenId: () => null);
      expect(sin.almacenId, isNull);
      expect(sin.query, isNot(contains('almacenId')));
    });

    test('dos consultas iguales son iguales y cuentan sus filtros', () {
      final base = ConsultaSinVentas.inicial(DateTime(2026, 11, 8));
      expect(base, ConsultaSinVentas.inicial(DateTime(2026, 11, 8, 23)));
      expect(base.activosFrente(base), 0);

      final otra = base.copiar(
        medida: MedidaSinVentas.unidades,
        marcaId: () => 2,
        incluirSinStock: true,
      );
      expect(otra == base, isFalse);
      expect(otra.activosFrente(base), 3);
      expect(base.copiar(desde: DateTime(2026, 10, 1)).activosFrente(base), 1);
    });
  });

  // ------------------------------------------------- Filtros sobre lo traído

  group('filtros del cliente', () {
    List<String> nombres(List<ProductoAnalisis> l) =>
        [for (final p in l) p.producto];

    test('sin filtros se ve todo', () {
      expect(filtrarProductos(_productos()), hasLength(4));
    });

    test('una tarjeta deja solo ese estado', () {
      expect(
        nombres(filtrarProductos(_productos(), estado: 'CRITICO')),
        ['ACEITE 1L'],
      );
      expect(
        nombres(filtrarProductos(_productos(), estado: 'SIN_BASE')),
        ['LECHE EVAPORADA'],
      );
      expect(filtrarProductos(_productos(), estado: 'SEGUIMIENTO'), isEmpty);
    });

    test('"productos sin ventas" son los críticos, en riesgo y en seguimiento', () {
      expect(
        nombres(filtrarProductos(_productos(), estado: claveEnCaida)),
        ['ACEITE 1L', 'ARROZ 5KG'],
      );
    });

    test('el buscador mira producto, código, marca y categoría', () {
      expect(nombres(filtrarProductos(_productos(), busqueda: 'aceite')), ['ACEITE 1L']);
      expect(nombres(filtrarProductos(_productos(), busqueda: 'p0003')), ['AZUCAR RUBIA']);
      expect(nombres(filtrarProductos(_productos(), busqueda: 'marca 2')), ['ARROZ 5KG']);
      expect(
        nombres(filtrarProductos(_productos(), busqueda: '  categoría 4 ')),
        ['LECHE EVAPORADA'],
      );
      expect(filtrarProductos(_productos(), busqueda: 'zzz'), isEmpty);
    });

    test('días sin movimiento: 15, 30, 60, 90 o más, o nunca vendidos', () {
      List<String> con(MovimientoSinVentas m) => nombres(
        filtrarProductos(
          _productos(),
          locales: FiltrosLocalesSinVentas(movimiento: m),
        ),
      );

      // Aceite 68 días, arroz 38, azúcar 3 y la leche 365 (nunca vendida).
      expect(con(MovimientoSinVentas.dias15), [
        'ACEITE 1L',
        'ARROZ 5KG',
        'LECHE EVAPORADA',
      ]);
      expect(con(MovimientoSinVentas.dias30), [
        'ACEITE 1L',
        'ARROZ 5KG',
        'LECHE EVAPORADA',
      ]);
      expect(con(MovimientoSinVentas.dias60), ['ACEITE 1L', 'LECHE EVAPORADA']);
      expect(con(MovimientoSinVentas.dias90), ['LECHE EVAPORADA']);
      expect(con(MovimientoSinVentas.nunca), ['LECHE EVAPORADA']);
    });

    test('stock: con, sin, desde y hasta', () {
      List<String> con(FiltrosLocalesSinVentas f) =>
          nombres(filtrarProductos(_productos(), locales: f));

      expect(con(const FiltrosLocalesSinVentas(stock: StockSinVentas.sin)), [
        'ARROZ 5KG',
      ]);
      expect(con(const FiltrosLocalesSinVentas(stock: StockSinVentas.con)), [
        'ACEITE 1L',
        'AZUCAR RUBIA',
        'LECHE EVAPORADA',
      ]);
      expect(con(const FiltrosLocalesSinVentas(stockDesde: 10)), [
        'ACEITE 1L',
        'AZUCAR RUBIA',
      ]);
      expect(con(const FiltrosLocalesSinVentas(stockHasta: 10)), [
        'ARROZ 5KG',
        'AZUCAR RUBIA',
        'LECHE EVAPORADA',
      ]);
      expect(
        con(const FiltrosLocalesSinVentas(stockDesde: 5, stockHasta: 10)),
        ['AZUCAR RUBIA', 'LECHE EVAPORADA'],
      );
    });

    test('los filtros se combinan y se cuentan', () {
      const f = FiltrosLocalesSinVentas(
        movimiento: MovimientoSinVentas.dias30,
        stock: StockSinVentas.con,
      );
      expect(f.activos, 2);
      expect(const FiltrosLocalesSinVentas().activos, 0);

      expect(
        nombres(
          filtrarProductos(
            _productos(),
            estado: claveEnCaida,
            busqueda: 'aceite',
            locales: f,
          ),
        ),
        ['ACEITE 1L'],
      );
      // El arroz está en caída pero no tiene stock.
      expect(
        filtrarProductos(
          _productos(),
          estado: 'RIESGO',
          locales: const FiltrosLocalesSinVentas(stock: StockSinVentas.con),
        ),
        isEmpty,
      );
    });

    test('los catálogos descartan inactivos y filas sin id', () {
      final opciones = OpcionCatalogo.desdeLista([
        {'id': 1, 'nombre': 'Central', 'activo': true},
        {'id': 2, 'nombre': 'Cerrado', 'activo': false},
        {'id': 3, 'nombre': 'Sin bandera'},
        {'nombre': 'Sin id'},
      ]);
      expect(opciones.map((o) => o.nombre), ['Central', 'Sin bandera']);
      expect(OpcionCatalogo.desdeLista(null), isEmpty);
    });
  });

  // --------------------------------------------------------------- Pantalla

  group('pantalla', () {
    testWidgets('pinta tarjetas, gráficos y la lista de productos', (
      tester,
    ) async {
      final api = _ApiFalsa();
      await _montar(tester, api);

      expect(tester.takeException(), isNull);
      expect(api.consultas, hasLength(1));

      // Las seis tarjetas, con sus rangos y detalles.
      expect(find.text('Venta perdida S/ 1,200'), findsOneWidget);
      expect(find.text('71 % o más'), findsOneWidget);
      expect(find.text('26 - 70 %'), findsOneWidget);
      expect(find.text('S/ 800 en stock'), findsOneWidget);
      // Las tarjetas se deslizan de lado: la última queda fuera de la pantalla.
      await tester.dragUntilVisible(
        find.text('Sin ventas el mes anterior'),
        find.byType(ListView).first,
        const Offset(-200, 0),
      );
      expect(find.text('0 - 10 %'), findsOneWidget);
      expect(find.text('No vendieron el mes anterior'), findsOneWidget);

      // Los tres gráficos.
      expect(find.byType(GraficoDona), findsOneWidget);
      expect(find.byType(GraficoBarrasH), findsOneWidget);
      expect(find.byType(GraficoLinea), findsOneWidget);
      expect(find.text('Distribución por estado'), findsOneWidget);
      expect(find.text('Categorías con mayor caída'), findsOneWidget);
      expect(find.text('Evolución de ventas'), findsOneWidget);
      // La dona lleva el total al centro y los % con un decimal.
      expect(find.text('4 productos analizados'), findsOneWidget);
      expect(find.textContaining('25.0%', findRichText: true), findsWidgets);

      // La lista, como tarjetas.
      expect(find.text('4 productos'), findsOneWidget);
      expect(find.text('ACEITE 1L'), findsOneWidget);
      expect(find.text('LECHE EVAPORADA'), findsOneWidget);
      expect(find.text('P0001 · Marca 1 · Categoría 1'), findsOneWidget);
      expect(find.text('Nunca'), findsOneWidget);
      expect(find.text('01/09/2026'), findsOneWidget);
      expect(find.text('−S/ 900'), findsOneWidget);
      expect(find.text('−90.0 %'), findsOneWidget);
    });

    testWidgets('tocar una tarjeta filtra la lista y volver a tocar la quita', (
      tester,
    ) async {
      await _montar(tester, _ApiFalsa());

      await tester.tap(find.text('71 % o más'));
      await tester.pumpAndSettle();
      expect(find.text('1 producto'), findsOneWidget);
      expect(find.text('ACEITE 1L'), findsOneWidget);
      expect(find.text('ARROZ 5KG'), findsNothing);

      await tester.tap(find.text('71 % o más'));
      await tester.pumpAndSettle();
      expect(find.text('4 productos'), findsOneWidget);

      // La primera tarjeta junta los que ya cayeron.
      await tester.tap(find.text('Venta perdida S/ 1,200'));
      await tester.pumpAndSettle();
      expect(find.text('2 productos'), findsOneWidget);
      expect(find.text('AZUCAR RUBIA'), findsNothing);
    });

    testWidgets('el buscador acota la lista', (tester) async {
      await _montar(tester, _ApiFalsa());

      await tester.enterText(find.byType(TextField).first, 'arroz');
      await tester.pumpAndSettle();

      expect(find.text('1 producto'), findsOneWidget);
      expect(find.text('ARROZ 5KG'), findsOneWidget);
      expect(find.text('ACEITE 1L'), findsNothing);
    });

    testWidgets('los filtros locales de los providers acotan la lista', (
      tester,
    ) async {
      final contenedor = await _montar(tester, _ApiFalsa());

      contenedor.read(localesSinVentasProvider.notifier).state =
          const FiltrosLocalesSinVentas(movimiento: MovimientoSinVentas.nunca);
      await tester.pumpAndSettle();

      expect(find.text('1 producto'), findsOneWidget);
      expect(find.text('LECHE EVAPORADA'), findsOneWidget);
      expect(find.text('ACEITE 1L'), findsNothing);
      // Las tarjetas y la dona siguen midiendo todos los productos.
      expect(find.text('4 productos analizados'), findsOneWidget);
    });

    testWidgets('los filtros del servidor vuelven a pedir con la consulta nueva', (
      tester,
    ) async {
      final api = _ApiFalsa();
      final contenedor = await _montar(tester, api);

      contenedor.read(consultaSinVentasProvider.notifier).state = contenedor
          .read(consultaSinVentasProvider)
          .copiar(criterio: CriterioSinVentas.dias, almacenId: () => 1);
      await tester.pumpAndSettle();

      expect(api.consultas, hasLength(2));
      expect(api.consultas.last.criterio, CriterioSinVentas.dias);
      expect(api.consultas.last.almacenId, 1);
    });

    testWidgets('la hoja de filtros aplica juntos los cambios', (tester) async {
      final api = _ApiFalsa();
      final contenedor = await _montar(tester, api);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Comparar con'), findsOneWidget);
      expect(find.text('Comparar por'), findsOneWidget);
      expect(find.text('Criterio'), findsOneWidget);
      expect(find.text('Sucursal'), findsOneWidget);
      expect(find.text('Incluir sin stock'), findsOneWidget);
      expect(find.text('Días sin movimiento'), findsOneWidget);
      expect(find.text('Stock desde'), findsOneWidget);
      expect(find.text('Aplicar'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Stock desde'), '10');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(contenedor.read(localesSinVentasProvider).stockDesde, 10);
      // Solo cambió algo local: el servidor no se vuelve a consultar.
      expect(api.consultas, hasLength(1));
      expect(find.text('2 productos'), findsOneWidget);
    });

    testWidgets('sin permiso en los catálogos la pantalla no falla', (
      tester,
    ) async {
      await _montar(tester, _ApiFalsa(sinPermisoEnCatalogos: true));

      expect(tester.takeException(), isNull);
      expect(find.text('4 productos'), findsOneWidget);

      // La hoja abre igual, con los selectores sin opciones.
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Sucursal'), findsOneWidget);
      expect(find.text('Aplicar'), findsOneWidget);
    });

    testWidgets('si el análisis falla lo dice y deja reintentar', (
      tester,
    ) async {
      final api = _ApiFalsa(falla: true);
      await _montar(tester, api);

      expect(tester.takeException(), isNull);
      expect(find.text('No se pudo cargar'), findsOneWidget);
      expect(find.text('El servidor no responde'), findsOneWidget);
      expect(find.byType(GraficoDona), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(api.consultas, hasLength(2));
    });
  });
}
