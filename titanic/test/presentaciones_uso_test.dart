import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/compartido/presentaciones_uso.dart';
import 'package:titanic/compartido/widgets/app_buscador_productos.dart';
import 'package:titanic/compartido/widgets/app_lineas_producto.dart';
import 'package:titanic/compartido/widgets/app_panel_producto.dart';
import 'package:titanic/features/maestros/datos/producto.dart';

Presentacion _pres({
  required int id,
  required String nombre,
  required double factor,
  bool esBase = false,
  bool esCompra = true,
  bool esVenta = true,
  bool activo = true,
}) => Presentacion(
  id: id,
  unidadId: 1,
  unidad: nombre,
  nombre: nombre,
  factor: factor,
  esBase: esBase,
  esCompra: esCompra,
  esVenta: esVenta,
  activo: activo,
);

Producto _producto({
  required int id,
  required String nombre,
  required String unidadBase,
  required List<Presentacion> presentaciones,
}) => Producto(
  id: id,
  codigo: 'P$id',
  nombre: nombre,
  descripcion: null,
  categoriaId: null,
  categoria: 'Abarrotes',
  marcaId: null,
  marca: 'Beltrán',
  unidadBaseId: 1,
  unidadBase: unidadBase,
  costoReferencia: 5,
  controlaStock: true,
  stockMinimo: 0,
  activo: true,
  presentaciones: presentaciones,
);

// Los tres casos reales que motivaron la regla.

/// Solo sale por caja: la unidad suelta no se compra ni se vende.
final _aceite = _producto(
  id: 1,
  nombre: 'ACEITE BELTRAN',
  unidadBase: 'UND',
  presentaciones: [
    _pres(
      id: 10,
      nombre: 'Unidad',
      factor: 1,
      esBase: true,
      esCompra: false,
      esVenta: false,
    ),
    _pres(id: 11, nombre: 'Caja 12UND', factor: 12),
  ],
);

/// Se vende suelto por kilo, pero se compra solo por saco.
final _camanejo = _producto(
  id: 2,
  nombre: 'CAMANEJO',
  unidadBase: 'KG',
  presentaciones: [
    _pres(
      id: 20,
      nombre: 'Kilogramo',
      factor: 1,
      esBase: true,
      esCompra: false,
    ),
    _pres(id: 21, nombre: 'Saco 50KG', factor: 50),
  ],
);

/// Kilo y bolsa se venden, solo el saco se compra.
final _frijol = _producto(
  id: 3,
  nombre: 'FRIJOL',
  unidadBase: 'KG',
  presentaciones: [
    _pres(
      id: 30,
      nombre: 'Kilogramo',
      factor: 1,
      esBase: true,
      esCompra: false,
    ),
    _pres(id: 31, nombre: 'Bolsa 10kg', factor: 10, esCompra: false),
    _pres(id: 32, nombre: 'Saco 50kg', factor: 50),
  ],
);

/// Sin ninguna presentación cargada: nada que apague la base.
final _sinPresentaciones = _producto(
  id: 4,
  nombre: 'ARROZ',
  unidadBase: 'KG',
  presentaciones: const [],
);

/// No se vende en ninguna presentación (sí se compra).
final _noSeVende = _producto(
  id: 5,
  nombre: 'MATERIA PRIMA',
  unidadBase: 'KG',
  presentaciones: [
    _pres(id: 50, nombre: 'Kilogramo', factor: 1, esBase: true, esVenta: false),
    _pres(id: 51, nombre: 'Saco 25KG', factor: 25, esVenta: false),
  ],
);

List<int> _valores(
  Producto p,
  UsoPresentacion? uso, {
  bool baseSiempre = false,
  int? actual,
}) => opcionesPresentacion(
  unidadBase: p.unidadBase,
  presentaciones: p.presentaciones,
  uso: uso,
  baseSiempre: baseSiempre,
  actual: actual,
).map((o) => o.valor).toList();

void main() {
  group('opciones y unidad inicial', () {
    test('ACEITE: sin unidad suelta, solo la caja y arranca en ella', () {
      for (final uso in UsoPresentacion.values) {
        expect(_valores(_aceite, uso), [11], reason: '$uso');
        expect(presentacionInicial(_aceite, uso), 11, reason: '$uso');
      }
    });

    test('CAMANEJO: se vende por kilo y por saco, se compra solo por saco', () {
      expect(_valores(_camanejo, UsoPresentacion.venta), [0, 21]);
      expect(presentacionInicial(_camanejo, UsoPresentacion.venta), 0);

      expect(_valores(_camanejo, UsoPresentacion.compra), [21]);
      expect(presentacionInicial(_camanejo, UsoPresentacion.compra), 21);
    });

    test('FRIJOL: en compra solo el saco de 50kg', () {
      expect(_valores(_frijol, UsoPresentacion.compra), [32]);
      expect(presentacionInicial(_frijol, UsoPresentacion.compra), 32);

      // En venta sí sirven el kilo y la bolsa.
      expect(_valores(_frijol, UsoPresentacion.venta), [0, 31, 32]);
    });

    test(
      'la base se llama como la unidad base del producto y las demás como su presentación',
      () {
        final opciones = opcionesPresentacion(
          unidadBase: _camanejo.unidadBase,
          presentaciones: _camanejo.presentaciones,
          uso: UsoPresentacion.venta,
        );

        expect(opciones.map((o) => o.nombre), ['KG', 'Saco 50KG']);
        expect(opciones.map((o) => o.factor), [1, 50]);
        // Nada de esto es una unidad que "ya no se vende": ninguna lleva nota.
        expect(opciones.every((o) => o.nota == null), isTrue);
      },
    );

    test('sin fila base en la lista se ofrece la base, como siempre', () {
      expect(_valores(_sinPresentaciones, UsoPresentacion.venta), [0]);
      expect(_valores(_sinPresentaciones, UsoPresentacion.compra), [0]);
      expect(presentacionInicial(_sinPresentaciones, UsoPresentacion.venta), 0);

      // Una lista con presentaciones pero sin la fila base tampoco la apaga.
      final soloCaja = _producto(
        id: 6,
        nombre: 'GASEOSA',
        unidadBase: 'UND',
        presentaciones: [_pres(id: 60, nombre: 'Caja 6UND', factor: 6)],
      );
      expect(_valores(soloCaja, UsoPresentacion.venta), [0, 60]);
    });

    test('si el producto trae varias filas base, basta con que una sirva', () {
      final dosBases = _producto(
        id: 7,
        nombre: 'DUPLICADA',
        unidadBase: 'KG',
        presentaciones: [
          _pres(
            id: 70,
            nombre: 'Kilo A',
            factor: 1,
            esBase: true,
            esVenta: false,
          ),
          _pres(id: 71, nombre: 'Kilo B', factor: 1, esBase: true),
        ],
      );

      expect(
        baseHabilitada(dosBases.presentaciones, UsoPresentacion.venta),
        isTrue,
      );
      expect(_valores(dosBases, UsoPresentacion.venta), [0]);
    });

    test('una presentación inactiva no se ofrece, ni la base inactiva', () {
      final inactivas = _producto(
        id: 8,
        nombre: 'DESCONTINUADO',
        unidadBase: 'KG',
        presentaciones: [
          _pres(
            id: 80,
            nombre: 'Kilogramo',
            factor: 1,
            esBase: true,
            activo: false,
          ),
          _pres(id: 81, nombre: 'Saco 50KG', factor: 50, activo: false),
          _pres(id: 82, nombre: 'Saco 25KG', factor: 25),
        ],
      );

      expect(_valores(inactivas, UsoPresentacion.venta), [82]);
    });

    test('producto que no se vende en nada: sin opciones y no se ofrece', () {
      expect(_valores(_noSeVende, UsoPresentacion.venta), isEmpty);
      expect(presentacionInicial(_noSeVende, UsoPresentacion.venta), isNull);

      final ofrecidos = productosConOpcion([
        _aceite,
        _noSeVende,
        _sinPresentaciones,
      ], UsoPresentacion.venta);
      expect(ofrecidos.map((p) => p.nombre), ['ACEITE BELTRAN', 'ARROZ']);

      // Sí se compra: ahí no se esconde.
      expect(
        productosConOpcion([
          _noSeVende,
        ], UsoPresentacion.compra).map((p) => p.nombre),
        ['MATERIA PRIMA'],
      );
    });

    test('sin uso valen todas las activas y no se esconde ningún producto', () {
      expect(_valores(_aceite, null), [0, 11]);
      expect(_valores(_frijol, null), [0, 31, 32]);
      expect(productosConOpcion([_noSeVende, _aceite], null), hasLength(2));
    });

    test(
      'baseSiempre ofrece la base aunque tenga las marcas apagadas (inventario)',
      () {
        // El ajuste de inventario cuenta lo que hay: una unidad suelta de algo que
        // solo se vende por caja es un conteo legítimo.
        expect(_valores(_aceite, UsoPresentacion.compra, baseSiempre: true), [
          0,
          11,
        ]);
        expect(_valores(_frijol, UsoPresentacion.compra, baseSiempre: true), [
          0,
          32,
        ]);
        expect(
          presentacionInicial(
            _aceite,
            UsoPresentacion.compra,
            baseSiempre: true,
          ),
          0,
        );
        expect(
          productosConOpcion(
            [_noSeVende],
            UsoPresentacion.venta,
            baseSiempre: true,
          ),
          hasLength(1),
        );
      },
    );
  });

  group('línea guardada con una unidad que ya no está permitida', () {
    test(
      'aparece marcada en vez de desaparecer: unidad base de ACEITE en una venta',
      () {
        final opciones = opcionesPresentacion(
          unidadBase: _aceite.unidadBase,
          presentaciones: _aceite.presentaciones,
          uso: UsoPresentacion.venta,
          actual: 0,
        );

        expect(opciones.map((o) => o.valor), [11, 0]);
        expect(opciones.first.nota, isNull);
        expect(opciones.last.nombre, 'UND');
        expect(opciones.last.nota, 'ya no se vende así');
      },
    );

    test(
      'en una compra la nota dice que ya no se compra así, con el nombre de la presentación',
      () {
        final opciones = opcionesPresentacion(
          unidadBase: _frijol.unidadBase,
          presentaciones: _frijol.presentaciones,
          uso: UsoPresentacion.compra,
          actual: 31,
        );

        expect(opciones.map((o) => o.valor), [32, 31]);
        expect(opciones.last.nombre, 'Bolsa 10kg');
        expect(opciones.last.factor, 10);
        expect(opciones.last.nota, 'ya no se compra así');
      },
    );

    test('una unidad permitida no se duplica ni se marca', () {
      final opciones = opcionesPresentacion(
        unidadBase: _camanejo.unidadBase,
        presentaciones: _camanejo.presentaciones,
        uso: UsoPresentacion.venta,
        actual: 21,
      );

      expect(opciones.map((o) => o.valor), [0, 21]);
      expect(opciones.every((o) => o.nota == null), isTrue);
    });

    test('sin uso el aviso es genérico', () {
      final opciones = opcionesPresentacion(
        unidadBase: 'KG',
        presentaciones: [
          _pres(id: 90, nombre: 'Saco', factor: 50, activo: false),
        ],
        actual: 90,
      );

      expect(opciones.last.valor, 90);
      expect(opciones.last.nota, 'no disponible');
    });
  });

  group('widgets', () {
    testWidgets(
      'el panel arranca en la caja cuando la unidad suelta no se vende',
      (tester) async {
        final agregadas = <LineaElegida>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AppPanelProducto(
                  productos: [_aceite, _noSeVende],
                  uso: UsoPresentacion.venta,
                  onAgregar: agregadas.addAll,
                ),
              ),
            ),
          ),
        );

        // El producto que no se vende en nada ni siquiera sale en la búsqueda.
        await tester.enterText(find.byType(TextField).first, 'materia');
        await tester.pumpAndSettle();
        expect(find.text('MATERIA PRIMA'), findsNothing);

        await tester.enterText(find.byType(TextField).first, 'aceite');
        await tester.pumpAndSettle();
        await tester.tap(find.text('ACEITE BELTRAN'));
        await tester.pumpAndSettle();

        // La unidad elegida es la caja; la suelta no se ofrece ni en el menú.
        expect(find.text('Caja 12UND · 12 UND'), findsOneWidget);
        await tester.tap(find.byType(DropdownButton<int>));
        await tester.pumpAndSettle();
        expect(find.text('UND'), findsNothing);
        await tester.tap(find.text('Caja 12UND · 12 UND').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.widgetWithText(TextField, '0'), '30');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Agregar producto'));
        await tester.pumpAndSettle();

        expect(agregadas.single.presentacionId, 11);
        expect(agregadas.single.presentacion, 'Caja 12UND');
      },
    );

    testWidgets('sin uso (inventario) el panel sigue ofreciendo la unidad base', (
      tester,
    ) async {
      final agregadas = <LineaElegida>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppPanelProducto(
                productos: [_aceite],
                paraVenta: false,
                onAgregar: agregadas.addAll,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'aceite');
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACEITE BELTRAN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();

      // Contar unidades sueltas de algo que solo se vende por caja es legítimo.
      expect(agregadas.single.presentacionId, 0);
      expect(agregadas.single.presentacion, 'UND');
    });

    testWidgets(
      'la hoja marca cada producto en su primera unidad usable y esconde el que no sirve',
      (tester) async {
        List<SeleccionProducto>? resultado;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    resultado = await mostrarBuscadorProductos(
                      context: context,
                      productos: [_aceite, _camanejo, _noSeVende],
                      uso: UsoPresentacion.venta,
                    );
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();

        // MATERIA PRIMA no se vende en nada: no se lista.
        expect(find.text('2 productos'), findsOneWidget);
        expect(find.text('MATERIA PRIMA'), findsNothing);

        await tester.tap(find.byType(Checkbox).at(0));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Checkbox).at(1));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Agregar (2)'));
        await tester.pumpAndSettle();

        // ACEITE arranca en su caja; CAMANEJO, que se vende suelto, en el kilo.
        expect(
          resultado!.map((s) => (s.producto.nombre, s.presentacionId)).toList(),
          [('ACEITE BELTRAN', 11), ('CAMANEJO', 0)],
        );
      },
    );

    testWidgets(
      'la tarjeta de la línea marca la unidad que ya no se vende así',
      (tester) async {
        final linea = LineaDocumento(
          productoId: _aceite.id,
          producto: _aceite.nombre,
          codigo: _aceite.codigo,
          unidadBase: _aceite.unidadBase,
          presentaciones: _aceite.presentaciones,
          uso: UsoPresentacion.venta,
          presentacionId: 0,
          cantidad: 5,
          importe: 3,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AppLineasProducto(
                  lineas: [linea],
                  onCambio: () {},
                  onEliminar: (_) {},
                ),
              ),
            ),
          ),
        );

        // El selector no queda en blanco: muestra lo guardado y dice qué pasó.
        expect(find.text('UND · ya no se vende así'), findsOneWidget);

        await tester.tap(find.byType(DropdownButton<int>));
        await tester.pumpAndSettle();
        expect(find.text('Caja 12UND'), findsOneWidget);
      },
    );

    testWidgets('la tarjeta de una línea permitida no lleva ninguna nota', (
      tester,
    ) async {
      final linea = LineaDocumento(
        productoId: _camanejo.id,
        producto: _camanejo.nombre,
        codigo: _camanejo.codigo,
        unidadBase: _camanejo.unidadBase,
        presentaciones: _camanejo.presentaciones,
        uso: UsoPresentacion.compra,
        presentacionId: 21,
        cantidad: 2,
        importe: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppLineasProducto(
                lineas: [linea],
                onCambio: () {},
                onEliminar: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Saco 50KG'), findsOneWidget);
      expect(find.textContaining('ya no se'), findsNothing);
    });
  });
}
