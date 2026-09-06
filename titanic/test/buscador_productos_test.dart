import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/compartido/widgets/app_buscador_productos.dart';
import 'package:titanic/features/maestros/datos/producto.dart';

Presentacion _presentacion({
  required int id,
  required String nombre,
  required double factor,
  bool esBase = false,
  bool esVenta = true,
  bool esCompra = true,
}) => Presentacion(
  id: id,
  unidadId: 1,
  unidad: nombre,
  nombre: nombre,
  factor: factor,
  esBase: esBase,
  esCompra: esCompra,
  esVenta: esVenta,
  activo: true,
);

Producto _producto({
  required int id,
  required String codigo,
  required String nombre,
  double? costoReferencia,
  List<Presentacion> presentaciones = const [],
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
  presentaciones: presentaciones,
);

final _productos = [
  _producto(id: 1, codigo: 'PROD001', nombre: 'arroz caserita', costoReferencia: 4),
  _producto(
    id: 2,
    codigo: 'PROD002',
    nombre: 'yogurt vainilla',
    costoReferencia: 7,
    presentaciones: [_presentacion(id: 20, nombre: 'Botella', factor: 1, esCompra: false)],
  ),
];

/// Abre la hoja y deja lo que devolvio en [resultado].
Future<void> _abrir(
  WidgetTester tester, {
  required bool paraVenta,
  required List<SeleccionProducto>? Function() leer,
  required void Function(List<SeleccionProducto>?) guardar,
  Map<int, double>? stock,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final r = await mostrarBuscadorProductos(
                context: context,
                productos: _productos,
                paraVenta: paraVenta,
                stock: stock,
              );
              guardar(r);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('agrega varios productos de una sola vez', (tester) async {
    List<SeleccionProducto>? resultado;

    await _abrir(
      tester,
      paraVenta: false,
      leer: () => resultado,
      guardar: (r) => resultado = r,
    );

    expect(find.text('Buscar productos'), findsOneWidget);
    expect(find.text('2 productos'), findsOneWidget);

    // Marcar los dos: en una compra el costo de referencia ya viene puesto,
    // asi que las filas quedan completas sin escribir nada.
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();

    expect(find.text('2 seleccionados'), findsOneWidget);

    await tester.tap(find.text('Agregar (2)'));
    await tester.pumpAndSettle();

    expect(resultado, isNotNull);
    expect(resultado!.length, 2);
    // El costo de referencia del producto se propone como importe.
    expect(resultado!.first.importe, 4);
    expect(resultado!.first.cantidad, 1);
  });

  testWidgets('una fila sin importe no se agrega', (tester) async {
    List<SeleccionProducto>? resultado;

    // En una venta el costo de referencia NO se propone: es lo que costo, no
    // lo que se cobra. La fila queda incompleta hasta que se escriba el precio.
    await _abrir(
      tester,
      paraVenta: true,
      leer: () => resultado,
      guardar: (r) => resultado = r,
    );

    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pumpAndSettle();

    expect(find.text('1 seleccionado'), findsOneWidget);
    // Marcado pero sin precio: el boton no ofrece agregar nada.
    expect(find.text('Agregar'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '').last, '25');
    await tester.pumpAndSettle();

    expect(find.text('Agregar (1)'), findsOneWidget);

    await tester.tap(find.text('Agregar (1)'));
    await tester.pumpAndSettle();

    expect(resultado!.single.importe, 25);
  });

  testWidgets('el buscador filtra por texto', (tester) async {
    await _abrir(tester, paraVenta: true, leer: () => null, guardar: (_) {});

    await tester.enterText(find.byType(TextField).first, 'yogurt');
    await tester.pumpAndSettle();

    expect(find.text('1 producto'), findsOneWidget);
    expect(find.text('arroz caserita'), findsNothing);
    expect(find.text('yogurt vainilla'), findsOneWidget);
  });

  testWidgets('muestra el stock del almacen que se le pasa', (tester) async {
    // Lo que ve el vendedor es lo del almacen de despacho: el producto 1 tiene
    // 12 y el 2 esta en cero, aunque en otro deposito hubiera de sobra.
    await _abrir(
      tester,
      paraVenta: true,
      leer: () => null,
      guardar: (_) {},
      stock: const {1: 12, 2: 0},
    );

    expect(find.text('12 KG'), findsOneWidget);
    expect(find.text('0 KG'), findsOneWidget);
  });

  testWidgets('sin stock declarado no pinta ninguna etiqueta', (tester) async {
    await _abrir(tester, paraVenta: true, leer: () => null, guardar: (_) {});

    expect(find.textContaining(' KG'), findsNothing);
  });

  testWidgets('en compra no se ofrece una presentacion solo de venta', (tester) async {
    await _abrir(tester, paraVenta: false, leer: () => null, guardar: (_) {});

    // "Botella" es esCompra: false — al comprar no debe aparecer como unidad.
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<int>).first);
    await tester.pumpAndSettle();

    expect(find.text('Botella'), findsNothing);
  });
}
