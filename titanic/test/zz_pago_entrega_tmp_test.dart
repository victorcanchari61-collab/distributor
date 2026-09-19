// TEMPORAL: verifica la pestaña Pago de la hoja de conversión. Se borra después.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titanic/compartido/widgets/app_alerta.dart';

import 'package:titanic/features/finanzas/datos/metodo_pago.dart';
import 'package:titanic/features/finanzas/estado/finanzas_controlador.dart';
import 'package:titanic/features/inventario/datos/almacen.dart';
import 'package:titanic/features/inventario/estado/inventario_controlador.dart';
import 'package:titanic/features/tms/datos/novedad.dart';
import 'package:titanic/features/tms/estado/novedades_controlador.dart';
import 'package:titanic/features/ventas/datos/nota_venta.dart';
import 'package:titanic/features/ventas/datos/pedido.dart';
import 'package:titanic/features/ventas/datos/ventas_api.dart';
import 'package:titanic/features/ventas/estado/ventas_controlador.dart';
import 'package:titanic/features/ventas/vistas/entrega_pedido_hoja.dart';

class _ApiFalsa implements VentasApi {
  Map<String, dynamic>? cuerpo;

  @override
  Future<List<Pedido>> pedidos() async => [];

  @override
  Future<NotaVenta> confirmarPedido(int id, Map<String, dynamic> c) async {
    cuerpo = c;
    return NotaVenta.desdeJson({
      'id': 1,
      'clienteId': 1,
      'fecha': '2026-09-19T10:00:00',
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _pedido = Pedido(
  id: 7,
  numero: 'PED-0007',
  clienteId: 1,
  cliente: 'Bodega Don Pepe',
  condicionPago: CondicionPago.credito,
  fecha: DateTime(2026, 9, 19),
  estado: EstadoPedido.pendiente,
  reservaStock: true,
  almacenId: 1,
  almacen: 'Principal',
  total: 50,
  detalle: const [
    LineaVenta(
      id: 11,
      productoId: 1,
      codigo: 'P1',
      producto: 'Arroz',
      unidadBase: 'KG',
      cantidadPresentacion: 10,
      cantidad: 10,
      precioUnitario: 5,
      precioPresentacion: 5,
      subtotal: 50,
    ),
  ],
);

Future<_ApiFalsa> _abrir(WidgetTester tester, {List<MetodoPagoOpcion>? metodos}) async {
  final api = _ApiFalsa();
  String? resultado;

  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ventasApiProvider.overrideWithValue(api),
        metodosPagoOpcionesProvider.overrideWith(
          (ref) async =>
              metodos ??
              const [
                MetodoPagoOpcion(id: 1, nombre: 'Caja', tipo: 'EFECTIVO'),
                MetodoPagoOpcion(id: 2, nombre: 'Yape', tipo: 'BILLETERA_DIGITAL'),
                MetodoPagoOpcion(id: 3, nombre: 'Plin', tipo: 'BILLETERA_DIGITAL'),
              ],
        ),
        opcionesMotivoProvider.overrideWith((ref) async => const <MotivoNovedad>[]),
        almacenesOpcionesProvider.overrideWith((ref) async => const <Almacen>[]),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await mostrarEntregaPedido(context, _pedido);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  addTearDown(() => resultado);
  _resultado = () => resultado;
  return api;
}

String? Function() _resultado = () => null;

void main() {
  testWidgets('Pago: agrega, autocompleta efectivo, cobra parcial y todo', (tester) async {
    final api = await _abrir(tester);

    expect(find.text('Entrega'), findsOneWidget);
    expect(find.text('Pago'), findsOneWidget);

    await tester.tap(find.text('Pago'));
    await tester.pumpAndSettle();

    expect(find.text('Acordado con el cliente:'), findsOneWidget);
    expect(find.text('Crédito'), findsOneWidget);
    expect(find.text('A cobrar'), findsOneWidget);
    expect(find.text('S/ 50.00'), findsNWidgets(2));
    expect(find.text('Cobrado ahora'), findsOneWidget);
    expect(find.text('Queda a crédito'), findsOneWidget);

    // Agregar pago -> tipo Efectivo -> método se autocompleta.
    await tester.tap(find.text('Agregar pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tipo de pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Efectivo').last);
    await tester.pumpAndSettle();
    expect(find.text('Caja'), findsOneWidget); // método autocompletado

    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '20');
    await tester.tap(find.text('Guardar pago'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cobro parcial'), findsOneWidget);
    expect(find.text('S/ 20.00'), findsWidgets);

    // Cobrar todo: 30 en efectivo, guardado.
    await tester.tap(find.text('Cobrar todo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cobrado completo'), findsOneWidget);

    // Convertir
    await tester.tap(find.text('Convertir en venta'));
    await tester.pumpAndSettle();

    expect(api.cuerpo, isNotNull);
    expect(api.cuerpo!['almacenId'], isNull);
    expect(api.cuerpo!['lineas'], isEmpty);
    expect(api.cuerpo!['pagos'], [
      {'metodoPagoId': 1, 'monto': 20.0},
      {'metodoPagoId': 1, 'monto': 30.0},
    ]);
    expect(_resultado(), 'Pedido convertido: venta al contado, cobrada (S/ 50.00).');
  });

  testWidgets('Pago sin guardar bloquea y sobrepago se rechaza', (tester) async {
    final api = await _abrir(tester);

    await tester.tap(find.text('Pago'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar pago'));
    await tester.pumpAndSettle();

    // Volver a Entrega y convertir: la validación lleva a Pago con el mensaje.
    await tester.tap(find.text('Entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Convertir en venta'));
    await tester.pumpAndSettle();

    expect(
      find.text('Hay un pago sin guardar: guárdalo con el visto o cancélalo antes de convertir.'),
      findsOneWidget,
    );
    expect(api.cuerpo, isNull);
    expect(find.text('Cobrado ahora'), findsOneWidget); // estamos en Pago

    // Sobrepago: 60 > 50
    await tester.tap(find.text('Tipo de pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Efectivo').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '60');
    await tester.tap(find.text('Guardar pago'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Con este pago se cobraría S/ 60.00'), findsOneWidget);

    // Cancelar descarta la fila nueva.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar pago'), findsNothing);
  });

  testWidgets('Sin cobro: crédito y mensaje de crédito', (tester) async {
    final api = await _abrir(tester);
    await tester.tap(find.text('Convertir en venta'));
    await tester.pumpAndSettle();
    expect(api.cuerpo!['pagos'], isEmpty);
    expect(_resultado(), 'Pedido convertido: venta a crédito por S/ 50.00.');
  });

  testWidgets('Sin métodos activos avisa', (tester) async {
    await _abrir(tester, metodos: const []);
    await tester.tap(find.text('Pago'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No hay métodos de pago activos'), findsOneWidget);
  });

  testWidgets('Editar/cancelar/quitar en pantalla angosta (320)', (tester) async {
    await _abrir(tester);
    tester.view.physicalSize = const Size(960, 2000);
    tester.view.devicePixelRatio = 3;
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cobrar todo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cobrado completo'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // badge de la pestaña

    await tester.tap(find.byTooltip('Editar pago de S/ 50.00'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar pago'), findsOneWidget);
    // El badge cuenta solo los guardados: la fila abierta no.
    expect(find.text('1'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '10');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar pago'), findsNothing);
    expect(find.textContaining('Cobrado completo'), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar pago de S/ 50.00'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Todavía no se cobró nada'), findsOneWidget);
    expect(find.textContaining('Cobrado completo'), findsNothing);
  });

  testWidgets('Recortar la entrega deja el cobro pasado: sobra y la entrega manda primero', (tester) async {
    final api = await _abrir(tester);

    await tester.tap(find.text('Pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cobrar todo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrega'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'KG'), '5');
    await tester.pumpAndSettle();

    // Sin motivo: la entrega se valida antes que el cobro.
    await tester.tap(find.text('Convertir en venta'));
    await tester.pumpAndSettle();
    expect(find.text('Elige el motivo por el que Arroz se entrega en menos.'), findsOneWidget);
    expect(api.cuerpo, isNull);

    await tester.tap(find.text('Pago'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lo cobrado supera el total en S/ 25.00'), findsOneWidget);
  });
}
