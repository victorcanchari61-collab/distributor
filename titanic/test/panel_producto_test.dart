import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/compartido/widgets/app_panel_producto.dart';
import 'package:titanic/features/maestros/datos/producto.dart';

Producto _producto({
  required int id,
  required String codigo,
  required String nombre,
  double? costoReferencia,
}) => Producto(
  id: id,
  codigo: codigo,
  nombre: nombre,
  descripcion: null,
  categoriaId: null,
  categoria: 'Granos',
  marcaId: null,
  marca: 'Gloria',
  unidadBaseId: 1,
  unidadBase: 'KG',
  costoReferencia: costoReferencia,
  controlaStock: true,
  stockMinimo: 0,
  activo: true,
  presentaciones: const [],
);

final _productos = [
  _producto(id: 1, codigo: 'PROD001', nombre: 'arroz caserita', costoReferencia: 4),
  _producto(id: 2, codigo: 'PROD002', nombre: 'yogurt vainilla', costoReferencia: 7),
];

Future<List<LineaElegida>> _montar(
  WidgetTester tester, {
  bool paraVenta = true,
  Map<int, double>? stock,
}) async {
  final agregadas = <LineaElegida>[];

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AppPanelProducto(
            productos: _productos,
            paraVenta: paraVenta,
            stock: stock,
            onAgregar: agregadas.addAll,
          ),
        ),
      ),
    ),
  );

  return agregadas;
}

void main() {
  testWidgets('escribir lista los productos sin abrir ninguna hoja', (tester) async {
    await _montar(tester);

    await tester.enterText(find.byType(TextField).first, 'arroz');
    await tester.pumpAndSettle();

    expect(find.text('arroz caserita'), findsOneWidget);
    expect(find.text('yogurt vainilla'), findsNothing);
    // La hoja de seleccion multiple no se abrio sola.
    expect(find.text('Buscar productos'), findsNothing);
  });

  testWidgets('la lista muestra el stock del almacen que se le pasa', (tester) async {
    await _montar(tester, stock: const {1: 12, 2: 0});

    await tester.enterText(find.byType(TextField).first, 'arroz');
    await tester.pumpAndSettle();

    expect(find.textContaining('12 KG'), findsOneWidget);
  });

  testWidgets('no lleva boton de filtros: se busca escribiendo', (tester) async {
    await _montar(tester);

    expect(find.byIcon(Icons.tune), findsNothing);
  });

  testWidgets('la lupa abre la hoja de seleccion multiple', (tester) async {
    await _montar(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('Buscar productos'), findsOneWidget);
  });

  testWidgets('agrega una linea con lo escrito en el panel', (tester) async {
    final agregadas = await _montar(tester);

    await tester.enterText(find.byType(TextField).first, 'yogurt');
    await tester.pumpAndSettle();
    await tester.tap(find.text('yogurt vainilla'));
    await tester.pumpAndSettle();

    // Al vender el importe arranca en cero: el costo de referencia es lo que
    // costo, no lo que se cobra, y proponerlo invita a vender a precio de compra.
    await tester.enterText(find.widgetWithText(TextField, '0'), '25');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();

    expect(agregadas.length, 1);
    expect(agregadas.first.producto.nombre, 'yogurt vainilla');
    expect(agregadas.first.cantidad, 1);
    expect(agregadas.first.importe, 25);

    // Vuelve a cero: la linea siguiente no arrastra nada de la anterior.
    expect(find.widgetWithText(TextField, 'yogurt vainilla'), findsNothing);
  });

  testWidgets('al comprar propone el costo de referencia', (tester) async {
    final agregadas = await _montar(tester, paraVenta: false);

    await tester.enterText(find.byType(TextField).first, 'arroz');
    await tester.pumpAndSettle();
    await tester.tap(find.text('arroz caserita'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();

    expect(agregadas.single.importe, 4);
  });

  testWidgets('sin producto elegido no se puede agregar', (tester) async {
    final agregadas = await _montar(tester);

    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();

    expect(agregadas, isEmpty);
  });
}
