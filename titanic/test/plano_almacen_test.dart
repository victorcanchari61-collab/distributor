import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';
import 'package:titanic/features/inventario/datos/almacen.dart';
import 'package:titanic/features/inventario/datos/inventario_api.dart';
import 'package:titanic/features/inventario/estado/inventario_controlador.dart';
import 'package:titanic/features/inventario/vistas/plano_almacen_pagina.dart';

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

/// Lo que devolveria el API, armado a mano.
class _ApiFalsa extends Fake implements InventarioApi {
  _ApiFalsa({
    required this.lugares,
    this.elementos = const [],
    this.productos = const [],
  });

  final List<Map<String, dynamic>> lugares;
  final List<Map<String, dynamic>> elementos;
  final List<Map<String, dynamic>> productos;

  @override
  Future<List<Almacen>> almacenesOpciones() async => [
    Almacen.desdeJson({
      'id': 1,
      'codigo': 'T3',
      'nombre': 'Tienda 3',
      'esPrincipal': true,
      'activo': true,
    }),
  ];

  @override
  Future<List<Ubicacion>> ubicaciones(int almacenId) async => [
    for (final l in lugares) Ubicacion.desdeJson(l),
  ];

  @override
  Future<PlanoAlmacen> plano(int almacenId) async => PlanoAlmacen.desdeJson({
    'almacenId': almacenId,
    'columnas': 24,
    'filas': 14,
    'elementos': elementos,
  });

  @override
  Future<ProductosUbicados> productosUbicados(int almacenId) async =>
      ProductosUbicados.desdeJson({
        'almacenId': almacenId,
        'lugares': lugares.length,
        'sinLugar': 0,
        'items': productos,
      });
}

Map<String, dynamic> _lugar(
  int id,
  String codigo, {
  int? padreId,
  String tipo = 'CUARTO',
  String? nombre,
  String? ruta,
  int productos = 0,
  List<int>? rect,
}) => {
  'id': id,
  'almacenId': 1,
  'padreId': padreId,
  'tipo': tipo,
  'tipoEtiqueta': tipo == 'PISO' ? 'Piso' : 'Lugar',
  'codigo': codigo,
  'nombre': nombre,
  'ruta': ruta ?? codigo,
  'nivel': padreId == null ? 0 : 1,
  'activo': true,
  'hijos': 0,
  'productos': productos,
  'planoX': rect?[0],
  'planoY': rect?[1],
  'planoAncho': rect?[2],
  'planoAlto': rect?[3],
};

/// Dos pisos: en P1 la cocina dibujada, un pasillo y un deposito sin dibujar;
/// en P2 la terraza.
_ApiFalsa _conPisos() => _ApiFalsa(
  lugares: [
    _lugar(10, 'P1', tipo: 'PISO', nombre: 'Planta baja'),
    _lugar(
      11,
      '01',
      padreId: 10,
      nombre: 'Cocina',
      ruta: 'P1-01',
      productos: 1,
      rect: [0, 0, 6, 4],
    ),
    _lugar(12, '02', padreId: 10, nombre: 'Depósito', ruta: 'P1-02'),
    _lugar(20, 'P2', tipo: 'PISO'),
    _lugar(
      21,
      '01',
      padreId: 20,
      nombre: 'Terraza',
      ruta: 'P2-01',
      productos: 1,
      rect: [2, 2, 8, 5],
    ),
  ],
  elementos: [
    {
      'id': 1,
      'pisoId': 10,
      'tipo': 'PASILLO',
      'nombre': 'Pasillo',
      'x': 6,
      'y': 0,
      'ancho': 2,
      'alto': 14,
    },
    {
      'id': 2,
      'pisoId': 10,
      'tipo': 'ESCALERA',
      'nombre': 'Escalera',
      'x': 20,
      'y': 10,
      'ancho': 4,
      'alto': 4,
    },
  ],
  productos: [
    {
      'productoId': 100,
      'codigo': 'AZU-01',
      'producto': 'Azúcar rubia',
      'unidadBase': 'KG',
      'stock': 12,
      'lugares': [
        {'ubicacionId': 11, 'ruta': 'P1-01', 'nombre': 'Cocina'},
      ],
    },
    {
      'productoId': 200,
      'codigo': 'ACE-02',
      'producto': 'Aceite vegetal',
      'unidadBase': 'UND',
      'stock': 30,
      'lugares': [
        {'ubicacionId': 21, 'ruta': 'P2-01', 'nombre': 'Terraza'},
      ],
    },
  ],
);

Future<void> _montar(WidgetTester tester, _ApiFalsa api) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionAlmacenProvider.overrideWithValue(const _AlmacenConSesion()),
        inventarioApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(theme: Tema.claro(), home: const PlanoAlmacenPagina()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'la ubicacion lee su rectangulo del plano, y sin el queda sin dibujar',
    () {
      final dibujado = Ubicacion.desdeJson({
        'id': 1,
        'planoX': 2,
        'planoY': 3.0,
        'planoAncho': 4,
        'planoAlto': 5,
      });
      expect(dibujado.dibujado, isTrue);
      expect(dibujado.planoY, 3);

      final suelto = Ubicacion.desdeJson({'id': 2, 'planoX': 1});
      expect(suelto.dibujado, isFalse);
    },
  );

  test(
    'la ubicacion lee sus partes del plano, y sin ellas queda sin partes',
    () {
      final enL = Ubicacion.desdeJson({
        'id': 1,
        'planoX': 0,
        'planoY': 0,
        'planoAncho': 4,
        'planoAlto': 2,
        'planoPartes': [
          {'x': 0, 'y': 2.0, 'ancho': 2, 'alto': 3.0},
        ],
      });
      expect(enL.planoPartes, hasLength(1));
      final parte = enL.planoPartes.single;
      expect([parte.x, parte.y, parte.ancho, parte.alto], [0, 2, 2, 3]);

      expect(Ubicacion.desdeJson({'id': 2}).planoPartes, isEmpty);
      expect(
        Ubicacion.desdeJson({'id': 3, 'planoPartes': null}).planoPartes,
        isEmpty,
      );
    },
  );

  testWidgets('un lugar en L es una sola figura: tocar su parte lo abre', (
    tester,
  ) async {
    await _montar(
      tester,
      _ApiFalsa(
        lugares: [
          {
            ..._lugar(
              1,
              'L1',
              nombre: 'Rodea la escalera',
              productos: 1,
              rect: [0, 0, 4, 2],
            ),
            'planoPartes': [
              {'x': 0, 'y': 2, 'ancho': 2, 'alto': 3},
            ],
          },
        ],
        productos: [
          {
            'productoId': 300,
            'codigo': 'HAR-01',
            'producto': 'Harina',
            'unidadBase': 'KG',
            'stock': 7,
            'lugares': [
              {'ubicacionId': 1, 'ruta': 'L1', 'nombre': 'Rodea la escalera'},
            ],
          },
        ],
      ),
    );

    // El rotulo y el contador van una sola vez.
    expect(find.text('L1'), findsOneWidget);
    expect(find.text('Rodea la escalera'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    final plano = tester.getRect(find.byType(InteractiveViewer));
    final celda = plano.width / 24;
    Offset centroDe(double x, double y) =>
        plano.topLeft + Offset((x + 0.5) * celda, (y + 0.5) * celda);

    // La esquina que no es del lugar (dentro de la caja que lo encierra) no
    // abre nada.
    await tester.tapAt(centroDe(3, 4));
    await tester.pumpAndSettle();
    expect(find.text('Harina'), findsNothing);

    // La parte de abajo es el mismo lugar.
    await tester.tapAt(centroDe(1, 4));
    await tester.pumpAndSettle();
    expect(find.text('Harina'), findsOneWidget);
    expect(find.text('7 KG'), findsOneWidget);
  });

  testWidgets('pinta el piso con sus pestañas y lista lo que falta dibujar', (
    tester,
  ) async {
    await _montar(tester, _conPisos());

    expect(find.text('P1 · Planta baja'), findsOneWidget);
    expect(find.text('P2'), findsOneWidget);
    expect(find.text('Cocina'), findsOneWidget);
    expect(find.text('Pasillo'), findsOneWidget);
    expect(find.text('Escalera'), findsOneWidget);
    expect(find.text('Sin dibujar en el plano (1)'), findsOneWidget);
    expect(find.text('P1-02'), findsOneWidget);
    expect(find.text('Terraza'), findsNothing);

    await tester.tap(find.text('P2'));
    await tester.pumpAndSettle();
    expect(find.text('Terraza'), findsOneWidget);
    expect(find.text('Cocina'), findsNothing);
  });

  testWidgets('tocar un lugar abre lo que hay con su stock', (tester) async {
    await _montar(tester, _conPisos());

    await tester.tap(find.text('Cocina'));
    await tester.pumpAndSettle();

    expect(find.text('Azúcar rubia'), findsOneWidget);
    expect(find.text('12 KG'), findsOneWidget);
  });

  testWidgets('buscar sin tildes encuentra el producto y lleva a su piso', (
    tester,
  ) async {
    await _montar(tester, _conPisos());

    await tester.enterText(find.byType(TextField), 'aceite');
    await tester.pumpAndSettle();
    expect(find.text('Aceite vegetal'), findsOneWidget);
    expect(find.text('P2-01 · Terraza'), findsOneWidget);

    // Esta en el otro piso: tocar el lugar cambia de piso y abre la hoja.
    await tester.tap(find.text('P2-01 · Terraza'));
    await tester.pumpAndSettle();
    expect(find.text('30 UND'), findsOneWidget);
    expect(find.text('Terraza'), findsWidgets);

    // Con tilde en el dato y sin ella en lo escrito.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'azucar');
    await tester.pumpAndSettle();
    expect(find.text('P1-01 · Cocina'), findsOneWidget);
  });

  testWidgets('un almacen sin pisos tiene un solo plano y sin pestañas', (
    tester,
  ) async {
    await _montar(
      tester,
      _ApiFalsa(
        lugares: [
          _lugar(1, '01', nombre: 'Mostrador', rect: [0, 0, 5, 3]),
        ],
      ),
    );

    expect(find.text('Mostrador'), findsOneWidget);
    expect(find.text('Sin piso'), findsNothing);
    expect(find.textContaining('Sin dibujar'), findsNothing);
  });

  testWidgets(
    'un almacen sin lugares explica que el plano se dibuja en el web',
    (tester) async {
      await _montar(tester, _ApiFalsa(lugares: const []));

      expect(
        find.text('Este almacén todavía no tiene lugares'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Inventario → Plano del almacén'),
        findsOneWidget,
      );
    },
  );
}
