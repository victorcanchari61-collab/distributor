import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/core/navegacion/menu.dart';
import 'package:titanic/core/red/cliente_api.dart';
import 'package:titanic/core/red/excepciones.dart';
import 'package:titanic/core/tema/colores.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';
import 'package:titanic/features/dashboard/datos/dashboard_api.dart';
import 'package:titanic/features/dashboard/datos/dashboard_modelos.dart';
import 'package:titanic/features/dashboard/estado/dashboard_controlador.dart';
import 'package:titanic/features/dashboard/estado/periodo_tablero.dart';
import 'package:titanic/features/dashboard/vistas/cobranza_dashboard_pagina.dart';
import 'package:titanic/features/dashboard/vistas/inventario_dashboard_pagina.dart';
import 'package:titanic/features/dashboard/vistas/rentabilidad_dashboard_pagina.dart';
import 'package:titanic/features/dashboard/vistas/reparto_dashboard_pagina.dart';
import 'package:titanic/features/dashboard/vistas/ventas_dashboard_pagina.dart';
import 'package:titanic/features/dashboard/widgets/grafico_barras.dart';
import 'package:titanic/features/dashboard/widgets/grafico_barras_h.dart';
import 'package:titanic/features/dashboard/widgets/grafico_calor.dart';
import 'package:titanic/features/dashboard/widgets/grafico_dispersion.dart';
import 'package:titanic/features/dashboard/widgets/grafico_dona.dart';
import 'package:titanic/features/dashboard/widgets/grafico_embudo.dart';
import 'package:titanic/features/dashboard/widgets/grafico_linea.dart';
import 'package:titanic/features/dashboard/widgets/grafico_medidor.dart';
import 'package:titanic/features/dashboard/widgets/grafico_util.dart';
import 'package:titanic/features/dashboard/widgets/marco_grafico.dart';
import 'package:titanic/features/dashboard/widgets/tarjeta_kpi.dart';

/// Sesion iniciada, para poder pintar pantallas internas.
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

/// Un día cualquiera de agosto-septiembre de 2026, contado desde el 21 de ago.
DateTime _dia(int i) => DateTime(2026, 8, 21 + i);

/// Lo que devuelve el backend cuando hay movimiento: cada gráfico con algo que
/// dibujar, incluidos los casos raros (días atípicos, un margen sin dato, una
/// categoría "Sin ...", una pérdida).
DashboardVentas _ventasConDatos() => DashboardVentas(
  desde: _dia(0),
  hasta: _dia(29),
  actual: const DashTotalesVentas(
    importe: 48250,
    notas: 96,
    clientes: 41,
    ticket: 502.6,
  ),
  anterior: const DashTotalesVentas(
    importe: 40100,
    notas: 88,
    clientes: 39,
    ticket: 455.7,
  ),
  serie: [
    for (var i = 0; i < 30; i++)
      DashDiaVenta(
        fecha: _dia(i),
        importe: i % 7 == 6 ? 0 : 1200.0 + (i * 37 % 900),
        notas: i % 7 == 6 ? 0 : 2 + i % 5,
        importeAnterior: 1000.0 + (i * 53 % 700),
      ),
  ],
  atipicos: const [
    DashAtipico(indice: 5, tipo: 'PICO'),
    DashAtipico(indice: 12, tipo: 'CAIDA'),
  ],
  mes: DashMes(
    nombre: 'septiembre',
    diaActual: 19,
    diasMes: 30,
    acumulado: 30500,
    proyectado: 48000,
    mesAnterior: 46000,
    mesAnteriorMismoPunto: 29000,
    serieActual: [for (var i = 0; i < 19; i++) 1600.0 * (i + 1)],
    serieAnterior: [for (var i = 0; i < 31; i++) 1500.0 * (i + 1)],
    // Vacía hasta hoy, y desde hoy arranca en lo acumulado.
    serieProyeccion: [
      for (var i = 0; i < 30; i++) i < 18 ? null : 30500.0 + (i - 18) * 1500,
    ],
  ),
  porVendedor: const [
    DashItem(nombre: 'Ana Ruiz', valor: 22000, cantidad: 40),
    DashItem(nombre: 'Luis Campos', valor: 18000, cantidad: 41),
    DashItem(nombre: 'Sin asignar', valor: 8250, cantidad: 15),
  ],
  porCategoria: const [
    DashItem(nombre: 'Abarrotes', valor: 30000),
    DashItem(nombre: 'Bebidas', valor: 12000),
    DashItem(nombre: 'Sin categoría', valor: 6250),
  ],
  porFormaPago: const [
    DashItem(nombre: 'Contado', valor: 36000),
    DashItem(nombre: 'Crédito', valor: 12250),
  ],
  topProductos: [
    for (var i = 0; i < 10; i++)
      DashItem(
        nombre: 'Producto con un nombre bastante largo número ${i + 1}',
        valor: 5000.0 - i * 400,
      ),
  ],
  pareto: [
    for (var i = 0; i < 8; i++)
      DashPareto(
        nombre: 'Cliente ${i + 1}',
        valor: 9000.0 - i * 900,
        acumulado: (i + 1) * 12.5,
      ),
  ],
  clientesAl80: 6,
  clientesTotal: 41,
  calor: [
    for (var d = 0; d < 6; d++)
      for (var h = 8; h < 18; h++)
        DashCalor(
          dia: d,
          hora: h,
          importe: ((d * 7 + h * 3) % 11) * 120.0,
          notas: (d + h) % 4,
        ),
  ],
);

/// La base de prueba: todo en cero. Las series traen sus 30 días, pero sin un
/// sol vendido; lo demás, listas vacías.
DashboardVentas _ventasVacias() => DashboardVentas(
  desde: _dia(0),
  hasta: _dia(29),
  serie: [for (var i = 0; i < 30; i++) DashDiaVenta(fecha: _dia(i))],
  mes: const DashMes(nombre: 'septiembre', diaActual: 19, diasMes: 30),
);

DashboardGanancias _gananciasConDatos() => DashboardGanancias(
  desde: _dia(0),
  hasta: _dia(29),
  importe: 48250,
  costo: 39000,
  ganancia: 9250,
  margen: 19.2,
  gananciaAnterior: 8000,
  margenAnterior: 20.5,
  lineasSinCosto: 3,
  serie: [
    for (var i = 0; i < 30; i++)
      DashDiaGanancia(
        fecha: _dia(i),
        importe: i % 7 == 6 ? 0 : 1500,
        ganancia: i % 7 == 6 ? 0 : (i == 4 ? -120 : 310.0 + i * 3),
        // Sin venta ese día: sin margen.
        margen: i % 7 == 6 ? null : (i == 4 ? -8 : 20.0 + (i % 5)),
      ),
  ],
  productos: [
    for (var i = 0; i < 12; i++)
      DashProductoGanancia(
        nombre: 'Producto ${i + 1}',
        categoria: 'Abarrotes',
        importe: 500.0 + i * 700,
        ganancia: 80.0 + i * 20,
        margen: i == 3 ? -4.5 : (i == 7 ? null : 8.0 + i * 1.7),
      ),
  ],
  porCategoria: const [
    DashItem(nombre: 'Abarrotes', valor: 6200),
    DashItem(nombre: 'Bebidas', valor: 3400),
    DashItem(nombre: 'Limpieza', valor: -350),
  ],
);

DashboardGanancias _gananciasVacias() => DashboardGanancias(
  desde: _dia(0),
  hasta: _dia(29),
  serie: [for (var i = 0; i < 30; i++) DashDiaGanancia(fecha: _dia(i))],
);

DashboardCobranza _cobranzaConDatos() => DashboardCobranza(
  desde: _dia(0),
  hasta: _dia(29),
  totalPorCobrar: 12400,
  cuentas: 9,
  clientes: 5,
  antiguedad: const [
    DashItem(nombre: '0–7 días', valor: 3000, cantidad: 3),
    DashItem(nombre: '8–15 días', valor: 2500, cantidad: 2),
    DashItem(nombre: '16–30 días', valor: 2900, cantidad: 2),
    DashItem(nombre: '31–60 días', valor: 2000, cantidad: 1),
    DashItem(nombre: 'Más de 60', valor: 2000, cantidad: 1),
  ],
  deudores: const [
    DashDeudor(
      cliente: 'Bodega San Martín de Porres',
      saldo: 4200,
      notas: 3,
      dias: 75,
    ),
    DashDeudor(cliente: 'Minimarket Lucía', saldo: 3100, notas: 2, dias: 22),
    DashDeudor(cliente: 'Juan Pérez', saldo: 900, notas: 1, dias: 5),
  ],
  cobradoPeriodo: 21000,
  metodos: const ['Efectivo', 'Yape', 'Transferencia'],
  cobros: [
    for (var i = 0; i < 30; i++)
      DashCobroDia(
        fecha: _dia(i),
        valores: [400.0 + i * 5, i % 3 == 0 ? 250 : 0, i % 5 == 0 ? 800 : 0],
      ),
  ],
  creditoOtorgado: 12250,
);

DashboardCobranza _cobranzaVacia() => DashboardCobranza(
  desde: _dia(0),
  hasta: _dia(29),
  antiguedad: const [
    DashItem(nombre: '0–7 días', valor: 0),
    DashItem(nombre: '8–15 días', valor: 0),
    DashItem(nombre: '16–30 días', valor: 0),
    DashItem(nombre: '31–60 días', valor: 0),
    DashItem(nombre: 'Más de 60', valor: 0),
  ],
);

DashboardInventario _inventarioConDatos() => DashboardInventario(
  valorTotal: 86400,
  productos: 120,
  cobertura: [
    for (var i = 0; i < 8; i++)
      DashCobertura(
        producto: 'Producto ${i + 1} con un nombre muy largo para el teléfono',
        stock: 40.0 + i * 12,
        unidad: 'UND',
        ventaDiaria: 5,
        dias: 2.0 + i * 9,
      ),
  ],
  salud: const [
    DashItem(nombre: 'Crítico', valor: 4),
    DashItem(nombre: 'Atención', valor: 9),
    DashItem(nombre: 'Sano', valor: 70),
    DashItem(nombre: 'Sobrestock', valor: 12),
    DashItem(nombre: 'Sin rotación', valor: 25),
    DashItem(nombre: 'Estado nuevo', valor: 1),
  ],
  valorPorCategoria: const [
    DashItem(nombre: 'Abarrotes', valor: 52000),
    DashItem(nombre: 'Bebidas', valor: 21000),
    DashItem(nombre: 'Limpieza', valor: 13400),
  ],
  dormido: const [
    DashItem(nombre: 'Producto parado A', valor: 3200),
    DashItem(nombre: 'Producto parado B', valor: 1800),
  ],
  dormidoTotal: 5000,
  vencimientos: const [
    DashItem(nombre: 'Vencido', valor: 400),
    DashItem(nombre: '0–15 días', valor: 900),
    DashItem(nombre: '16–30 días', valor: 0),
    DashItem(nombre: '31–60 días', valor: 1500),
    DashItem(nombre: '61–90 días', valor: 700),
  ],
);

DashboardInventario _inventarioVacio() => const DashboardInventario(
  vencimientos: [
    DashItem(nombre: 'Vencido', valor: 0),
    DashItem(nombre: '0–15 días', valor: 0),
    DashItem(nombre: '16–30 días', valor: 0),
    DashItem(nombre: '31–60 días', valor: 0),
    DashItem(nombre: '61–90 días', valor: 0),
  ],
);

DashboardReparto _repartoConDatos({bool conNovedades = true}) =>
    DashboardReparto(
      desde: _dia(0),
      hasta: _dia(29),
      serie: [
        for (var i = 0; i < 30; i++)
          DashDiaPedidos(
            fecha: _dia(i),
            confirmados: 3 + i % 4,
            pendientes: i % 3,
            anulados: i % 6 == 0 ? 1 : 0,
          ),
      ],
      embudo: const [
        DashItem(nombre: 'Pedidos tomados', valor: 120),
        DashItem(nombre: 'Convertidos a venta', valor: 100),
        DashItem(nombre: 'Entregados completos', valor: 70),
        DashItem(nombre: 'Cobrados del todo', valor: 30),
      ],
      novedadesPorMotivo: conNovedades
          ? const [
              DashItem(nombre: 'Cliente ausente', valor: 900, cantidad: 4),
              DashItem(nombre: 'Sin motivo', valor: 300, cantidad: 1),
            ]
          : null,
      importeNovedades: conNovedades ? 1200 : 0,
      entregaCompleta: 82.5,
    );

DashboardReparto _repartoVacio({bool conNovedades = true}) => DashboardReparto(
  desde: _dia(0),
  hasta: _dia(29),
  serie: [for (var i = 0; i < 30; i++) DashDiaPedidos(fecha: _dia(i))],
  embudo: const [
    DashItem(nombre: 'Pedidos tomados', valor: 0),
    DashItem(nombre: 'Convertidos a venta', valor: 0),
    DashItem(nombre: 'Entregados completos', valor: 0),
    DashItem(nombre: 'Cobrados del todo', valor: 0),
  ],
  novedadesPorMotivo: conNovedades ? const [] : null,
);

/// API de mentira: no toca la red y anota cada llamada.
class _ApiFalsa extends DashboardApi {
  _ApiFalsa({
    this.vacia = false,
    this.falla = false,
    this.conNovedades = true,
    this.espera,
  }) : super(ClienteApi());

  final bool vacia;
  final bool falla;
  final bool conNovedades;

  /// Si viene, la respuesta espera a que se complete: para ver el esqueleto.
  final Completer<void>? espera;

  /// "ventas 2026-08-21 2026-09-19", una por llamada.
  final llamadas = <String>[];

  Future<T> _responder<T>(
    String tablero,
    DateTime? desde,
    DateTime? hasta,
    T Function() datos,
  ) async {
    llamadas.add('$tablero $desde $hasta');
    if (espera != null) await espera!.future;
    if (falla) throw const ApiExcepcion('El servidor no responde');
    return datos();
  }

  @override
  Future<DashboardVentas> ventas(DateTime desde, DateTime hasta) => _responder(
    'ventas',
    desde,
    hasta,
    () => vacia ? _ventasVacias() : _ventasConDatos(),
  );

  @override
  Future<DashboardGanancias> ganancias(DateTime desde, DateTime hasta) =>
      _responder(
        'ganancias',
        desde,
        hasta,
        () => vacia ? _gananciasVacias() : _gananciasConDatos(),
      );

  @override
  Future<DashboardCobranza> cobranza(DateTime desde, DateTime hasta) =>
      _responder(
        'cobranza',
        desde,
        hasta,
        () => vacia ? _cobranzaVacia() : _cobranzaConDatos(),
      );

  @override
  Future<DashboardInventario> inventario() => _responder(
    'inventario',
    null,
    null,
    () => vacia ? _inventarioVacio() : _inventarioConDatos(),
  );

  @override
  Future<DashboardReparto> reparto(DateTime desde, DateTime hasta) =>
      _responder(
        'reparto',
        desde,
        hasta,
        () => vacia
            ? _repartoVacio(conNovedades: conNovedades)
            : _repartoConDatos(conNovedades: conNovedades),
      );
}

/// Monta una pantalla en un telefono comun y con alto de sobra: el ListView
/// solo construye lo que se ve, y aqui interesa que se construya todo.
Future<void> _montar(
  WidgetTester tester,
  Widget pagina,
  _ApiFalsa api, {
  Size pantalla = const Size(375, 7000),
  bool esperar = true,
}) async {
  tester.view.physicalSize = pantalla;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionAlmacenProvider.overrideWithValue(const _AlmacenConSesion()),
        dashboardApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(theme: Tema.claro(), home: pagina),
    ),
  );
  if (esperar) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Las cinco pantallas con lo que las distingue.
final _tableros =
    <({String nombre, Widget pagina, String titulo, String ruta})>[
      (
        nombre: 'ventas',
        pagina: const VentasDashboardPagina(),
        titulo: 'Ventas por día',
        ruta: '/dashboard/ventas',
      ),
      (
        nombre: 'rentabilidad',
        pagina: const RentabilidadDashboardPagina(),
        titulo: 'Ganancia y margen por día',
        ruta: '/dashboard/rentabilidad',
      ),
      (
        nombre: 'cobranza',
        pagina: const CobranzaDashboardPagina(),
        titulo: 'Cuánto hace que se debe',
        ruta: '/dashboard/cobranza',
      ),
      (
        nombre: 'inventario',
        pagina: const InventarioDashboardPagina(),
        titulo: 'Cuánto dura el stock',
        ruta: '/dashboard/inventario',
      ),
      (
        nombre: 'reparto',
        pagina: const RepartoDashboardPagina(),
        titulo: 'Pedidos por día',
        ruta: '/dashboard/reparto',
      ),
    ];

Future<void> _mostrarGrafico(WidgetTester tester, Type tipo) async {
  await tester.ensureVisible(find.byType(tipo).first);
  await tester.pump();
}

void main() {
  // ------------------------------------------------------------- Formatos

  group('formatos es-PE', () {
    test('dinero con miles y sin decimales de sobra', () {
      expect(moneda(1234), 'S/ 1,234');
      expect(moneda(0), 'S/ 0');
      expect(moneda(1234567.5), 'S/ 1,234,568');
      expect(moneda(1234.5, 2), 'S/ 1,234.50');
      expect(moneda(-1234), 'S/ -1,234');
      // Lo que se redondea a cero no lleva signo.
      expect(moneda(-0.2), 'S/ 0');
    });

    test('compacto para los ejes', () {
      expect(compacto(950), '950');
      expect(compacto(1000), '1 mil');
      expect(compacto(12345), '12.3 mil');
      expect(compacto(1250000), '1.3 M');
      expect(compacto(-12345), '-12.3 mil');
      expect(compacto(0), '0');
    });

    test('porcentajes, variaciones y frases', () {
      expect(porcentaje(12.345), '12.3%');
      expect(porcentaje(90, 0), '90%');
      expect(variacion(110, 100), closeTo(10, 1e-9));
      // Sin período anterior no hay con qué comparar: nada de "+∞%".
      expect(variacion(50, 0), isNull);
      expect(
        fraseVariacion(12.4, 'los 30 días anteriores'),
        '+12% frente a los 30 días anteriores',
      );
      expect(fraseVariacion(-5, 'el mes pasado'), '−5% frente a el mes pasado');
      expect(fraseVariacion(0.2, 'x'), 'Igual que x');
      expect(fraseVariacion(null, 'x'), 'Sin x con qué comparar');
    });

    test('días de calle: sin zona horaria', () {
      // La "Z" del backend NO significa instante: el 5 de septiembre sigue siendo 5.
      final dia = diaDeJson('2026-09-05T00:00:00Z');
      expect((dia.year, dia.month, dia.day), (2026, 9, 5));
      expect(diaCorto(dia), '5 set');
      expect(diaLargo(dia), 'sáb 5 set');
      // Sin fecha, no revienta.
      expect(diaDeJson(null).year, 1970);
    });

    test('la escala es redonda y nunca divide entre cero', () {
      final e = escala(0, 4173);
      expect(e.pasos, [0, 2000, 4000, 6000]);
      expect(e.max, 6000);

      // Todo en cero: un rango de 0 a 1, no un 0/0.
      final cero = escala(0, 0);
      expect((cero.min, cero.max), (0, 1));

      // Con negativos, el cero queda dentro.
      final neg = escala(-120, 900);
      expect(neg.min, lessThan(0));
      expect(neg.pasos, contains(0));

      // Basura numérica: no entra en un ciclo infinito.
      expect(escala(double.nan, double.infinity).max, 1);
    });

    test('mediana de listas vacías, pares e impares', () {
      expect(mediana([]), 0);
      expect(mediana([3]), 3);
      expect(mediana([1, 9, 3]), 3);
      expect(mediana([1, 2, 3, 10]), 2.5);
    });
  });

  // -------------------------------------------------------------- Período

  group('período', () {
    test('los cuatro atajos cuentan hacia atrás desde hoy, incluido', () {
      final a = PeriodoTablero.atajos(DateTime(2026, 9, 19, 14, 30));

      expect(a.map((p) => p.etiqueta), [
        '7 días',
        '30 días',
        'Este mes',
        '90 días',
      ]);
      expect(a[0].desde, DateTime(2026, 9, 13));
      expect(a[1].desde, DateTime(2026, 8, 21));
      expect(a[2].desde, DateTime(2026, 9, 1));
      expect(a.every((p) => p.hasta == DateTime(2026, 9, 19)), isTrue);

      expect(a.map((p) => p.dias), [7, 30, 19, 90]);
      expect(PeriodoTablero.predeterminado(DateTime(2026, 9, 19)).id, '30');
    });

    test('un rango propio se queda en días, sin hora', () {
      final p = PeriodoTablero.propio(
        DateTime(2026, 9, 1, 8),
        DateTime(2026, 9, 3, 23, 59),
      );
      expect(p.id, 'custom');
      expect(p.dias, 3);
      expect(p.hasta, DateTime(2026, 9, 3));
    });
  });

  // -------------------------------------------------------------- Modelos

  group('modelos', () {
    test('leen el JSON del backend: fechas como días, nulos como nulos', () {
      final v = DashboardVentas.desdeJson({
        'desde': '2026-08-21T00:00:00Z',
        'hasta': '2026-09-19T00:00:00Z',
        'soloPropio': true,
        'actual': {'importe': 100.5, 'notas': 3, 'clientes': 2, 'ticket': 33.5},
        'serie': [
          {
            'fecha': '2026-09-05T00:00:00Z',
            'importe': 10,
            'notas': 1,
            'importeAnterior': 4.5,
          },
        ],
        'atipicos': [
          {'indice': 0, 'tipo': 'CAIDA'},
        ],
        'mes': {
          'nombre': 'septiembre',
          'diasMes': 30,
          'serieProyeccion': [null, 5, 7.5],
        },
      });

      expect(v.soloPropio, isTrue);
      expect(v.actual.importe, 100.5);
      expect(v.serie.single.fecha, DateTime(2026, 9, 5));
      expect(v.atipicos.single.esPico, isFalse);
      expect(v.mes.serieProyeccion, [null, 5.0, 7.5]);
      // Lo que no vino, en cero o vacío.
      expect(v.anterior.importe, 0);
      expect(v.pareto, isEmpty);
      expect(v.calor, isEmpty);
    });

    test('las novedades nulas se distinguen de las vacías', () {
      final sinPermiso = DashboardReparto.desdeJson({
        'novedadesPorMotivo': null,
        'entregaCompleta': null,
      });
      expect(sinPermiso.novedadesPorMotivo, isNull);
      expect(sinPermiso.entregaCompleta, isNull);

      final sinNovedades = DashboardReparto.desdeJson({
        'novedadesPorMotivo': [],
        'entregaCompleta': 91,
      });
      expect(sinNovedades.novedadesPorMotivo, isEmpty);
      expect(sinNovedades.entregaCompleta, 91);
    });

    test('un cuerpo vacío no revienta', () {
      expect(DashboardVentas.desdeJson(const {}).serie, isEmpty);
      expect(DashboardGanancias.desdeJson(const {}).margen, isNull);
      expect(DashboardCobranza.desdeJson(const {}).metodos, isEmpty);
      expect(DashboardInventario.desdeJson(const {}).cobertura, isEmpty);
      expect(DashboardReparto.desdeJson(const {}).embudo, isEmpty);
    });
  });

  // ----------------------------------------------------------------- Menú

  test('el grupo Dashboard va primero, en índigo, con sus cinco vistas', () {
    final grupo = menuGrupos.first;

    expect(grupo.id, 'dashboard');
    expect(grupo.color, const Color(0xFF4F46E5));
    expect(grupo.items.map((i) => i.id), [
      'dashboard.ventas',
      'dashboard.rentabilidad',
      'dashboard.cobranza',
      'dashboard.inventario',
      'dashboard.reparto',
    ]);
    // Todas tienen pantalla: ninguna sale con el punto gris de "pendiente".
    expect(grupo.items.every((i) => !i.pendiente), isTrue);
    expect(Colores.modulos['dashboard'], grupo.color);
  });

  // ------------------------------------------------------- Los 5 tableros

  group('con datos', () {
    for (final t in _tableros) {
      testWidgets('${t.nombre}: se construye completo y sin desbordes', (
        tester,
      ) async {
        final api = _ApiFalsa();
        await _montar(tester, t.pagina, api);

        expect(tester.takeException(), isNull);
        expect(find.text(t.titulo), findsOneWidget);
        // Con datos no queda ningún esqueleto ni ningún "sin datos".
        expect(find.byType(Esqueleto), findsNothing);
        expect(find.text('Sin datos en este período'), findsNothing);
        expect(find.byType(TarjetaKpi), findsNWidgets(4));
        expect(api.llamadas, hasLength(1));
      });
    }

    testWidgets('ventas: sus gráficos y sus conclusiones', (tester) async {
      await _montar(tester, const VentasDashboardPagina(), _ApiFalsa());

      // Indicadores.
      for (final k in [
        'Ventas',
        'Ticket promedio',
        'Ventas realizadas',
        'Clientes que compraron',
      ]) {
        expect(find.text(k), findsWidgets, reason: k);
      }
      // Una vez en el indicador y otra en el centro de la dona de categorías.
      expect(find.text('S/ 48,250'), findsWidgets);

      // Gráficos.
      expect(find.byType(GraficoLinea), findsNWidgets(2));
      expect(find.byType(GraficoCalor), findsOneWidget);
      expect(find.byType(GraficoBarras), findsOneWidget);
      expect(find.byType(GraficoBarrasH), findsNWidgets(2));
      expect(find.byType(GraficoDona), findsNWidgets(2));

      // Conclusiones escritas.
      expect(
        find.text(
          '+20% frente a los 30 días anteriores · 2 días fuera de lo normal',
        ),
        findsOneWidget,
      );
      expect(find.text('Avance de septiembre'), findsOneWidget);
      expect(
        find.textContaining('Cierre proyectado', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('6 de 41 clientes hacen el 80% de lo vendido'),
        findsOneWidget,
      );
    });

    testWidgets('rentabilidad: matriz de productos y avisos de costo', (
      tester,
    ) async {
      await _montar(tester, const RentabilidadDashboardPagina(), _ApiFalsa());

      expect(find.byType(GraficoDispersion), findsOneWidget);
      expect(find.byType(GraficoBarras), findsOneWidget);
      expect(find.byType(GraficoBarrasH), findsOneWidget);
      expect(find.text('3 líneas sin costo conocido'), findsOneWidget);
      expect(find.text('19.2%'), findsOneWidget);
      // La conclusión de la matriz: cuántos venden mucho y dejan poco.
      expect(
        find.textContaining(
          'menos que el margen de la casa (19.2%)',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('cobranza: antigüedad, deudores y cobros apilados', (
      tester,
    ) async {
      await _montar(tester, const CobranzaDashboardPagina(), _ApiFalsa());

      expect(find.byType(GraficoBarras), findsNWidgets(2));
      expect(find.byType(GraficoBarrasH), findsOneWidget);
      // 4 mil de 12.4 mil pasan de 30 días: 32%.
      expect(find.text('32% de la deuda pasa de 30 días'), findsOneWidget);
      expect(
        find.text('La deuda más vieja tiene más de 60 días'),
        findsOneWidget,
      );
      expect(find.textContaining('a crédito se dio S/ 12,250'), findsOneWidget);
    });

    testWidgets('inventario: sin selector de período', (tester) async {
      await _montar(tester, const InventarioDashboardPagina(), _ApiFalsa());

      expect(find.text('7 días'), findsNothing);
      expect(find.byType(GraficoBarrasH), findsNWidgets(2));
      expect(find.byType(GraficoDona), findsNWidgets(2));
      expect(find.byType(GraficoBarras), findsOneWidget);
      expect(
        find.text(
          '1 producto se acaba en menos de una semana al ritmo de venta actual',
        ),
        findsOneWidget,
      );
    });

    testWidgets('reparto: embudo, medidor y novedades', (tester) async {
      await _montar(tester, const RepartoDashboardPagina(), _ApiFalsa());

      expect(find.byType(GraficoEmbudo), findsOneWidget);
      expect(find.byType(GraficoMedidor), findsOneWidget);
      expect(find.text('83%'), findsWidgets); // 82.5, redondeado
      expect(find.text('No entregado'), findsWidgets);
      expect(find.text('Por qué no llegó completo'), findsOneWidget);
    });

    testWidgets(
      'reparto: sin permiso de Novedades no hay ese gráfico ni ese indicador',
      (tester) async {
        await _montar(
          tester,
          const RepartoDashboardPagina(),
          _ApiFalsa(conNovedades: false),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(TarjetaKpi), findsNWidgets(3));
        expect(find.text('No entregado'), findsNothing);
        expect(find.text('Por qué no llegó completo'), findsNothing);
        // Lo demás sigue.
        expect(find.byType(GraficoEmbudo), findsOneWidget);
        expect(find.byType(GraficoMedidor), findsOneWidget);
      },
    );
  });

  group('sin datos (la base de prueba: todo en cero)', () {
    for (final t in _tableros) {
      testWidgets('${t.nombre}: pinta sus estados vacíos sin romperse', (
        tester,
      ) async {
        await _montar(tester, t.pagina, _ApiFalsa(vacia: true));

        expect(tester.takeException(), isNull);
        expect(find.byType(Esqueleto), findsNothing);
        expect(find.text(t.titulo), findsOneWidget);
        // Los indicadores siguen, en cero.
        expect(find.byType(TarjetaKpi), findsWidgets);
        // Ningún gráfico con datos: el marco dice que no hay nada.
        expect(find.byType(GraficoLinea), findsNothing);
        expect(find.byType(GraficoBarras), findsNothing);
        expect(find.byType(GraficoDispersion), findsNothing);
        expect(find.byIcon(Icons.bar_chart_rounded), findsWidgets);
      });
    }

    testWidgets('ventas: el mensaje de cada marco', (tester) async {
      await _montar(
        tester,
        const VentasDashboardPagina(),
        _ApiFalsa(vacia: true),
      );

      expect(find.text('Sin datos en este período'), findsNWidgets(8));
      expect(find.text('S/ 0'), findsWidgets);
    });

    testWidgets('cobranza: nadie debe nada', (tester) async {
      await _montar(
        tester,
        const CobranzaDashboardPagina(),
        _ApiFalsa(vacia: true),
      );

      expect(find.text('Nadie debe nada'), findsOneWidget);
      expect(find.text('Sin cuentas por cobrar'), findsOneWidget);
      expect(find.text('Sin deudores'), findsOneWidget);
      expect(find.text('Sin cobros en el período'), findsOneWidget);
      expect(find.text('Nada atrasado'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('inventario: nada parado ni por vencer', (tester) async {
      await _montar(
        tester,
        const InventarioDashboardPagina(),
        _ApiFalsa(vacia: true),
      );

      expect(find.text('Nada parado'), findsOneWidget);
      expect(find.text('Nada vence en 90 días'), findsOneWidget);
      expect(
        find.text('Todavía no hay ventas para calcular el ritmo'),
        findsOneWidget,
      );
      expect(find.text('Ningún producto se acaba esta semana'), findsOneWidget);
    });

    testWidgets('reparto: el medidor dice "—" y las novedades están vacías', (
      tester,
    ) async {
      await _montar(
        tester,
        const RepartoDashboardPagina(),
        _ApiFalsa(vacia: true),
      );

      // El medidor sigue ahí: sin entregas su respuesta es "—", no un 0%.
      expect(find.byType(GraficoMedidor), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      expect(find.text('Sin novedades en el período'), findsOneWidget);
    });

    testWidgets('rentabilidad: la matriz pide al menos dos productos', (
      tester,
    ) async {
      await _montar(
        tester,
        const RentabilidadDashboardPagina(),
        _ApiFalsa(vacia: true),
      );

      expect(
        find.text('Hacen falta al menos dos productos vendidos'),
        findsOneWidget,
      );
    });
  });

  group('estados de carga y error', () {
    testWidgets('mientras llegan los datos hay esqueletos, no gráficos', (
      tester,
    ) async {
      final espera = Completer<void>();
      await _montar(
        tester,
        const VentasDashboardPagina(),
        _ApiFalsa(espera: espera),
        esperar: false,
      );

      // 4 indicadores + los 8 marcos.
      expect(find.byType(Esqueleto), findsNWidgets(12));
      expect(find.byType(GraficoLinea), findsNothing);

      espera.complete();
      await tester.pumpAndSettle();
      expect(find.byType(Esqueleto), findsNothing);
      expect(find.byType(GraficoLinea), findsNWidgets(2));
    });

    for (final t in _tableros) {
      testWidgets('${t.nombre}: si falla, cada gráfico lo dice', (
        tester,
      ) async {
        await _montar(tester, t.pagina, _ApiFalsa(falla: true));

        expect(tester.takeException(), isNull);
        expect(find.text('El servidor no responde'), findsWidgets);
        expect(find.byType(Esqueleto), findsNothing);
        expect(find.byType(TarjetaKpi), findsNothing);
      });
    }

    testWidgets('un error que no es del API dice algo entendible', (
      tester,
    ) async {
      final contenedor = ProviderContainer(
        overrides: [dashboardApiProvider.overrideWithValue(_ApiFalsa())],
      );
      addTearDown(contenedor.dispose);

      final bloque = bloqueDe<int>(
        AsyncError(StateError('x'), StackTrace.empty),
      );
      expect(bloque.error, 'No pudimos cargar este dashboard.');
      expect(bloque.datos, isNull);
      expect(bloqueDe<int>(const AsyncLoading()).cargando, isTrue);
      expect(bloqueDe<int>(const AsyncData(3)).listo, isTrue);
    });
  });

  group('período y actualizar', () {
    testWidgets('elegir un atajo vuelve a pedir con el rango nuevo', (
      tester,
    ) async {
      final api = _ApiFalsa();
      await _montar(tester, const VentasDashboardPagina(), api);

      final semana = PeriodoTablero.atajos()[0];
      await tester.tap(find.text('7 días'));
      await tester.pumpAndSettle();

      expect(api.llamadas, hasLength(2));
      expect(api.llamadas.last, 'ventas ${semana.desde} ${semana.hasta}');
      expect(find.text('Ventas por día'), findsOneWidget);
      // El de 7 días cuenta 7 días para comparar.
      expect(find.textContaining('los 7 días anteriores'), findsWidgets);
    });

    testWidgets('cada tablero conserva su propio período', (tester) async {
      await _montar(tester, const VentasDashboardPagina(), _ApiFalsa());

      await tester.tap(find.text('7 días'));
      await tester.pumpAndSettle();

      final contenedor = ProviderScope.containerOf(
        tester.element(find.byType(VentasDashboardPagina)),
      );
      expect(contenedor.read(periodoVentasProvider).id, '7');
      // Los demás siguen en 30 días: cambiar Ventas no mueve a Cobranza.
      expect(contenedor.read(periodoCobranzaProvider).id, '30');
      expect(contenedor.read(periodoRentabilidadProvider).id, '30');
      expect(contenedor.read(periodoRepartoProvider).id, '30');
      await tester.pumpAndSettle();
    });

    testWidgets('el botón Actualizar vuelve a pedir los datos', (tester) async {
      final api = _ApiFalsa();
      await _montar(tester, const CobranzaDashboardPagina(), api);

      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();

      expect(api.llamadas, hasLength(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tirar hacia abajo también actualiza', (tester) async {
      final api = _ApiFalsa();
      await _montar(
        tester,
        const InventarioDashboardPagina(),
        api,
        pantalla: const Size(375, 900),
      );

      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(api.llamadas, hasLength(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'actualizar aunque el servidor falle no deja una excepción sin atender',
      (tester) async {
        final api = _ApiFalsa(falla: true);
        await _montar(tester, const CobranzaDashboardPagina(), api);

        await tester.tap(find.byTooltip('Actualizar'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('El servidor no responde'), findsWidgets);
      },
    );
  });

  // ------------------------------------------------------ Toques y detalle

  group('al tocar', () {
    testWidgets('una línea deja el globo con el día y sus valores', (
      tester,
    ) async {
      await _montar(tester, const VentasDashboardPagina(), _ApiFalsa());

      await _mostrarGrafico(tester, LineChart);
      final linea = find.byType(LineChart).first;
      await tester.tapAt(tester.getCenter(linea));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tocar otro punto lo mueve, y tocar fuera de los ejes no revienta.
      await tester.tapAt(tester.getCenter(linea) + const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('las barras con su línea de margen responden al toque', (
      tester,
    ) async {
      await _montar(tester, const RentabilidadDashboardPagina(), _ApiFalsa());

      await _mostrarGrafico(tester, BarChart);
      await tester.tapAt(tester.getCenter(find.byType(BarChart).first));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'la dona resalta la porción de su leyenda y la suelta al tocar otra vez',
      (tester) async {
        await _montar(tester, const VentasDashboardPagina(), _ApiFalsa());

        // Antes de tocar, el centro dice el total.
        expect(find.text('VENDIDO'), findsOneWidget);

        await tester.ensureVisible(find.text('Bebidas'));
        await tester.tap(find.text('Bebidas'));
        await tester.pumpAndSettle();
        expect(find.text('BEBIDAS'), findsOneWidget);
        expect(find.text('VENDIDO'), findsNothing);

        await tester.tap(find.text('Bebidas'));
        await tester.pumpAndSettle();
        expect(find.text('VENDIDO'), findsOneWidget);
      },
    );

    testWidgets('el mapa de calor muestra el detalle de la celda tocada', (
      tester,
    ) async {
      await _montar(tester, const VentasDashboardPagina(), _ApiFalsa());

      expect(find.text('Toca una celda para ver el detalle'), findsOneWidget);

      final mapa = find
          .descendant(
            of: find.byType(GraficoCalor),
            matching: find.byType(CustomPaint),
          )
          .first;
      await tester.ensureVisible(mapa);
      // La primera celda del lunes: 8 h.
      final esquina = tester.getTopLeft(mapa);
      await tester.tapAt(esquina + const Offset(30 + 8, 8));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Lun · 8:00', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Toca una celda para ver el detalle'), findsNothing);

      // Fuera de la cuadrícula, se suelta.
      await tester.tapAt(esquina + const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.text('Toca una celda para ver el detalle'), findsOneWidget);
    });

    testWidgets('la matriz de productos elige el punto más cercano', (
      tester,
    ) async {
      await _montar(tester, const RentabilidadDashboardPagina(), _ApiFalsa());

      expect(find.text('Toca un punto para ver el producto'), findsOneWidget);

      final lienzo = find
          .descendant(
            of: find.byType(GraficoDispersion),
            matching: find.byType(CustomPaint),
          )
          .first;
      await tester.ensureVisible(lienzo);
      // Un toque en cualquier lugar del plano elige un punto si hay uno a menos
      // de 28 px; se prueba en una rejilla para no depender de la escala.
      final origen = tester.getTopLeft(lienzo);
      final tam = tester.getSize(lienzo);
      var elegido = false;
      for (var x = 60.0; x < tam.width && !elegido; x += 20) {
        for (var y = 20.0; y < tam.height - 40 && !elegido; y += 20) {
          await tester.tapAt(origen + Offset(x, y));
          await tester.pump();
          elegido = find
              .text('Toca un punto para ver el producto')
              .evaluate()
              .isEmpty;
        }
      }
      expect(elegido, isTrue);
      expect(
        find.textContaining('de margen', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'tocar una fila de barras horizontales muestra el nombre completo',
      (tester) async {
        await _montar(tester, const CobranzaDashboardPagina(), _ApiFalsa());

        await tester.ensureVisible(find.text('Juan Pérez'));
        await tester.tap(find.text('Juan Pérez'));
        await tester.pumpAndSettle();

        expect(find.textContaining('S/ 900 · 5 d'), findsWidgets);
      },
    );
  });

  // ---------------------------------------------------- Cada gráfico suelto

  group('gráficos con datos límite', () {
    Future<void> montarSuelto(
      WidgetTester tester,
      Widget grafico, {
      double ancho = 320,
    }) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.claro(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(width: ancho, child: grafico),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('línea de un solo punto, de todo ceros y de puros huecos', (
      tester,
    ) async {
      await montarSuelto(
        tester,
        const GraficoLinea(
          etiquetas: ['5 set'],
          series: [
            SerieLinea(
              id: 'a',
              nombre: 'A',
              color: Colors.blue,
              valores: [120],
            ),
          ],
        ),
      );
      await montarSuelto(
        tester,
        GraficoLinea(
          etiquetas: List.generate(30, (i) => '$i'),
          series: [
            SerieLinea(
              id: 'a',
              nombre: 'A',
              color: Colors.blue,
              valores: List.filled(30, 0),
              area: true,
            ),
          ],
        ),
      );
      await montarSuelto(
        tester,
        GraficoLinea(
          etiquetas: List.generate(5, (i) => '$i'),
          series: [
            SerieLinea(
              id: 'a',
              nombre: 'A',
              color: Colors.blue,
              valores: List.filled(5, null),
            ),
          ],
        ),
      );
      // Sin etiquetas ni series: no dibuja nada, no falla.
      await montarSuelto(tester, const GraficoLinea(etiquetas: [], series: []));
    });

    testWidgets('línea con más de 60 días y una marca sobre un hueco', (
      tester,
    ) async {
      await montarSuelto(
        tester,
        GraficoLinea(
          etiquetas: List.generate(90, (i) => '${i + 1} set'),
          series: [
            SerieLinea(
              id: 'a',
              nombre: 'A',
              color: Colors.blue,
              valores: List.generate(90, (i) => i * 10.0),
            ),
            SerieLinea(
              id: 'b',
              nombre: 'B',
              color: Colors.red,
              punteada: true,
              valores: List.generate(90, (i) => i < 40 ? null : i * 9.0),
            ),
          ],
          marcas: const [
            MarcaLinea(
              indice: 10,
              serie: 'b',
              color: Colors.green,
              titulo: 'sobre un hueco',
            ),
            MarcaLinea(
              indice: 89,
              serie: 'a',
              color: Colors.green,
              titulo: 'cierre',
            ),
          ],
        ),
      );
    });

    testWidgets('barras: ceros, negativos con línea de margen, y un solo día', (
      tester,
    ) async {
      await montarSuelto(
        tester,
        const GraficoBarras(
          etiquetas: ['a', 'b', 'c'],
          series: [
            SerieBarra(
              id: 's',
              nombre: 'S',
              color: Colors.green,
              valores: [0, 0, 0],
            ),
          ],
        ),
      );
      await montarSuelto(
        tester,
        GraficoBarras(
          etiquetas: const ['a', 'b', 'c', 'd'],
          series: const [
            SerieBarra(
              id: 's',
              nombre: 'S',
              color: Colors.green,
              valores: [300, -120, 0, 80],
            ),
          ],
          colorDe: (v, i) => v < 0 ? Colors.red : Colors.green,
          linea: LineaSecundaria(
            nombre: 'Margen',
            color: Colors.orange,
            valores: const [20, -8, null, 12],
            formato: (n) => '${n.round()}%',
          ),
        ),
      );
      await montarSuelto(
        tester,
        GraficoBarras(
          etiquetas: const ['solo'],
          series: const [
            SerieBarra(
              id: 's',
              nombre: 'S',
              color: Colors.green,
              valores: [50],
            ),
          ],
          linea: LineaSecundaria(
            nombre: 'Acum',
            color: Colors.orange,
            valores: const [100],
            formato: (n) => '${n.round()}%',
            max: 100,
          ),
        ),
      );
      // Apiladas con una serie que trae menos valores que días.
      await montarSuelto(
        tester,
        const GraficoBarras(
          apilado: true,
          etiquetas: ['a', 'b', 'c'],
          series: [
            SerieBarra(
              id: 'x',
              nombre: 'X',
              color: Colors.green,
              valores: [5, 3, 0],
            ),
            SerieBarra(id: 'y', nombre: 'Y', color: Colors.amber, valores: [1]),
          ],
        ),
      );
    });

    testWidgets('dona: todo en cero, una sola porción y valores negativos', (
      tester,
    ) async {
      await montarSuelto(
        tester,
        const GraficoDona(
          porciones: [
            PorcionDona(nombre: 'A', valor: 0),
            PorcionDona(nombre: 'B', valor: 0),
          ],
        ),
      );
      await montarSuelto(
        tester,
        const GraficoDona(porciones: [PorcionDona(nombre: 'A', valor: 10)]),
      );
      await montarSuelto(
        tester,
        const GraficoDona(
          porciones: [
            PorcionDona(nombre: 'A', valor: 10),
            PorcionDona(nombre: 'B', valor: -3),
          ],
        ),
      );
      await montarSuelto(tester, const GraficoDona(porciones: []));
      // Ancha: la leyenda pasa al costado.
      await montarSuelto(
        tester,
        const GraficoDona(
          porciones: [
            PorcionDona(nombre: 'A', valor: 10),
            PorcionDona(nombre: 'B', valor: 5),
          ],
        ),
        ancho: 380,
      );
    });

    testWidgets('barras horizontales: ceros, negativos y nada', (tester) async {
      await montarSuelto(
        tester,
        const GraficoBarrasH(
          items: [
            ItemBarraH(nombre: 'A', valor: 0),
            ItemBarraH(nombre: 'B', valor: 0),
          ],
        ),
      );
      await montarSuelto(
        tester,
        const GraficoBarrasH(
          items: [
            ItemBarraH(nombre: 'Pérdida', valor: -50),
            ItemBarraH(nombre: 'Ganancia', valor: 200),
          ],
        ),
      );
      await montarSuelto(tester, const GraficoBarrasH(items: []));
    });

    testWidgets('mapa de calor sin celdas', (tester) async {
      await montarSuelto(tester, const GraficoCalor(celdas: []));
      await montarSuelto(
        tester,
        const GraficoCalor(
          celdas: [CeldaCalor(dia: 6, hora: 23, valor: 5, detalle: 'x')],
        ),
      );
    });

    testWidgets('dispersión con un punto, con todos iguales y sin cuadrantes', (
      tester,
    ) async {
      await montarSuelto(
        tester,
        const GraficoDispersion(
          etiquetaX: 'X',
          etiquetaY: 'Y',
          puntos: [
            PuntoDispersion(
              nombre: 'P',
              x: 10,
              y: 5,
              color: Colors.blue,
              detalle: 'd',
              rotulo: true,
            ),
          ],
        ),
      );
      await montarSuelto(
        tester,
        const GraficoDispersion(
          etiquetaX: 'X',
          etiquetaY: 'Y',
          cuadrantes: CuadrantesDispersion(
            x: 0,
            y: 0,
            rotulos: ['a', 'b', 'c', 'd'],
          ),
          puntos: [
            PuntoDispersion(
              nombre: 'P',
              x: 0,
              y: 0,
              color: Colors.blue,
              detalle: 'd',
            ),
            PuntoDispersion(
              nombre: 'Q',
              x: 0,
              y: 0,
              color: Colors.red,
              detalle: 'd',
            ),
          ],
        ),
      );
      await montarSuelto(
        tester,
        const GraficoDispersion(etiquetaX: 'X', etiquetaY: 'Y', puntos: []),
      );
    });

    testWidgets('embudo y medidor con datos límite', (tester) async {
      await montarSuelto(
        tester,
        const GraficoEmbudo(
          etapas: [
            EtapaEmbudo(nombre: 'Tomados', valor: 0),
            EtapaEmbudo(nombre: 'Convertidos', valor: 0),
          ],
        ),
      );
      await montarSuelto(tester, const GraficoEmbudo(etapas: []));
      await montarSuelto(
        tester,
        const GraficoMedidor(valor: null, titulo: 't', meta: 90),
      );
      await montarSuelto(
        tester,
        const GraficoMedidor(valor: 250, titulo: 't', meta: 90),
      );
      await montarSuelto(
        tester,
        const GraficoMedidor(
          valor: 40,
          titulo: 't',
          meta: 90,
          mejorAlto: false,
        ),
      );
    });

    testWidgets(
      'tarjetas de indicadores: serie plana, de un punto y valor largo',
      (tester) async {
        await montarSuelto(
          tester,
          Column(
            children: const [
              TarjetaKpi(
                titulo: 'Plana',
                valor: 'S/ 1',
                serie: [5, 5, 5],
                cambio: 0,
              ),
              TarjetaKpi(
                titulo: 'Un punto',
                valor: 'S/ 1',
                serie: [5],
                cambio: null,
              ),
              TarjetaKpi(
                titulo:
                    'Un título larguísimo que no cabe en una tarjeta angosta',
                valor: 'S/ 123,456,789,012',
                cambio: -12.4,
                bajarEsBueno: true,
                nota:
                    'Una nota que también es larga y ocupa más de dos renglones en una tarjeta angosta',
              ),
            ],
          ),
          ancho: 170,
        );
      },
    );
  });

  test('cada pantalla dice su ruta y la ruta está en el menú', () {
    expect(
      VentasDashboardPagina.ruta,
      resolverRuta('/dashboard/ventas').item?.ruta,
    );
    expect(
      RentabilidadDashboardPagina.ruta,
      resolverRuta('/dashboard/rentabilidad').item?.ruta,
    );
    expect(
      CobranzaDashboardPagina.ruta,
      resolverRuta('/dashboard/cobranza').item?.ruta,
    );
    expect(
      InventarioDashboardPagina.ruta,
      resolverRuta('/dashboard/inventario').item?.ruta,
    );
    expect(
      RepartoDashboardPagina.ruta,
      resolverRuta('/dashboard/reparto').item?.ruta,
    );
  });
}
