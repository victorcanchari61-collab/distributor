import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/compartido/formato.dart';
import 'package:titanic/compartido/widgets/app_campo.dart';
import 'package:titanic/compartido/widgets/app_selector.dart';
import 'package:titanic/core/red/cliente_api.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/maestros/datos/catalogo.dart';
import 'package:titanic/features/maestros/datos/maestros_api.dart';
import 'package:titanic/features/maestros/datos/producto.dart';
import 'package:titanic/features/maestros/estado/maestros_controlador.dart';
import 'package:titanic/features/maestros/vistas/producto_formulario.dart';

/// El peso se guarda por UNA unidad base y de ahi sale el de cualquier
/// cantidad. El endpoint REEMPLAZA el producto con lo que le llega: si la app
/// edita un producto y no reenvia `pesoUnidadBase`, borra el que se puso desde
/// la web. Estos tests fijan que viaja, y que el costo —que se guarda con ocho
/// decimales— vuelve al centimo cuando se dice por presentacion.

Map<String, dynamic> _presJson({
  required int id,
  required String nombre,
  required double factor,
  bool esBase = false,
}) => {
  'id': id,
  'unidadId': 1,
  'unidad': 'Litro',
  'nombre': nombre,
  'factor': factor,
  'esBase': esBase,
  'esCompra': true,
  'esVenta': true,
  'activo': true,
};

/// Botella de 0.92 kg que ademas se compra por caja de 12: la caja pesa 11.04.
Map<String, dynamic> _productoJson({
  double? peso = 0.92,
  double? costo,
  double? precio,
}) => {
  'id': 5,
  'codigo': 'ACE-01',
  'nombre': 'ACEITE BELTRAN',
  'unidadBaseId': 1,
  'unidadBase': 'LT',
  'stockMinimo': 10,
  'costoReferencia': ?costo,
  'precioReferencia': ?precio,
  'pesoUnidadBase': ?peso,
  'presentaciones': [
    _presJson(id: 10, nombre: 'Litro', factor: 1, esBase: true),
    _presJson(id: 11, nombre: 'Caja 12 LT', factor: 12),
  ],
};

/// API de mentira: guarda lo que el formulario envia, sin tocar la red.
class _ApiFalso extends MaestrosApi {
  _ApiFalso() : super(ClienteApi());

  /// Cuerpo de POST /producto.
  Map<String, dynamic>? creado;

  /// Cuerpo de PUT /producto/{id}.
  Map<String, dynamic>? actualizado;

  @override
  Future<List<UnidadMedida>> unidades() async => const [
    UnidadMedida(id: 1, codigo: 'LT', nombre: 'Litro', activo: true),
  ];

  @override
  Future<List<Categoria>> categorias() async => const [];

  @override
  Future<List<Marca>> marcas() async => const [];

  @override
  Future<List<Producto>> productos() async => const [];

  @override
  Future<Producto> crearProducto(Map<String, dynamic> cuerpo) async {
    creado = cuerpo;
    return Producto.desdeJson(_productoJson());
  }

  @override
  Future<Producto> actualizarProducto(
    int id,
    Map<String, dynamic> cuerpo,
  ) async {
    actualizado = cuerpo;
    return Producto.desdeJson(_productoJson());
  }

  @override
  Future<Presentacion> actualizarPresentacion(
    int presentacionId,
    Map<String, dynamic> cuerpo,
  ) async => Presentacion.desdeJson({'id': presentacionId, 'unidadId': 1});

  @override
  Future<Presentacion> agregarPresentacion(
    int productoId,
    Map<String, dynamic> cuerpo,
  ) async => Presentacion.desdeJson({'id': 99, 'unidadId': 1});
}

/// Pantalla desde la que se abre el formulario, como hace la lista de
/// productos: al guardar el formulario hace `pop` y necesita una ruta debajo.
class _Lanzador extends StatelessWidget {
  const _Lanzador(this.producto);

  final Producto? producto;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductoFormulario(producto: producto),
          ),
        ),
        child: const Text('Abrir'),
      ),
    ),
  );
}

Future<_ApiFalso> _abrir(WidgetTester tester, {Producto? producto}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final api = _ApiFalso();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [maestrosApiProvider.overrideWithValue(api)],
      child: MaterialApp(theme: Tema.claro(), home: _Lanzador(producto)),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();

  return api;
}

/// Guardar termina con un aviso que se retira solo a los 3 segundos: hay que
/// dejar correr el reloj o el test acaba con un temporizador pendiente.
Future<void> _guardar(WidgetTester tester, {bool nuevo = false}) async {
  await tester.tap(find.text(nuevo ? 'Crear' : 'Guardar'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

/// Los campos de la pestaña Datos, en el orden en que se pintan: codigo,
/// nombre, descripcion, costo, precio de venta, stock minimo y peso.
///
/// Costo, precio y peso se escriben sobre la presentacion MAS GRANDE (aqui la caja de 12) y se
/// guardan por unidad base: 11.04 la caja son 0.92 el litro.
Finder _campo(int n) => find.descendant(
  of: find.byType(AppCampo).at(n),
  matching: find.byType(TextField),
);

Finder get _campoCosto => _campo(3);
Finder get _campoPrecio => _campo(4);
Finder get _campoPeso => _campo(6);

void main() {
  group('modelo', () {
    test('lee el peso por unidad base', () {
      final producto = Producto.desdeJson(_productoJson());

      expect(producto.pesoUnidadBase, 0.92);
    });

    test('sin peso queda en null: no todo producto se pesa', () {
      final producto = Producto.desdeJson(_productoJson(peso: null));

      expect(producto.pesoUnidadBase, isNull);
    });
  });

  group('formulario de producto', () {
    /*
     * El caso que borraba el peso puesto desde la web: abrir el producto,
     * corregir cualquier otra cosa y guardar. El PUT reemplaza el registro,
     * asi que el campo tiene que viajar aunque nadie lo haya tocado.
     */
    testWidgets('guardar sin tocar el peso lo reenvia tal cual', (
      tester,
    ) async {
      final api = await _abrir(
        tester,
        producto: Producto.desdeJson(_productoJson()),
      );

      await _guardar(tester);

      expect(api.actualizado?['pesoUnidadBase'], 0.92);
    });

    testWidgets('el peso tecleado viaja en el alta', (tester) async {
      final api = await _abrir(tester);

      await tester.enterText(_campo(0), 'ACE-02');
      await tester.enterText(_campo(1), 'ACEITE NUEVO');
      // Un producto nuevo aun no tiene presentaciones: el peso se escribe sobre la unidad base.
      await tester.enterText(_campoPeso, '0.92');
      await tester.pumpAndSettle();

      // Sin unidad base el formulario no deja guardar.
      await tester.tap(find.byType(AppSelector<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Litro (LT)').last);
      await tester.pumpAndSettle();

      await _guardar(tester, nuevo: true);

      expect(api.creado?['pesoUnidadBase'], closeTo(0.92, 1e-9));
    });

    testWidgets(
      'borrar el peso lo manda en null: el producto deja de pesarse',
      (tester) async {
        final api = await _abrir(
          tester,
          producto: Producto.desdeJson(_productoJson()),
        );

        await tester.enterText(_campoPeso, '');
        await tester.pumpAndSettle();
        await _guardar(tester);

        expect(api.actualizado, containsPair('pesoUnidadBase', isNull));
      },
    );

    testWidgets('el peso se lee sobre la presentacion mas grande', (
      tester,
    ) async {
      await _abrir(tester, producto: Producto.desdeJson(_productoJson()));

      // Se guarda por litro (0.92) y se muestra como se dice en el almacen: la caja de 12 pesa 11.04.
      expect(tester.widget<TextField>(_campoPeso).controller?.text, '11.04');
    });

    testWidgets(
      'el precio de venta se escribe por presentacion y viaja por unidad base',
      (tester) async {
        final api = await _abrir(
          tester,
          producto: Producto.desdeJson(_productoJson()),
        );

        // 310 la caja de 12 son 25.8333... el litro.
        await tester.enterText(_campoPrecio, '310');
        await tester.pumpAndSettle();
        await _guardar(tester);

        expect(api.actualizado?['precioReferencia'], closeTo(310 / 12, 1e-9));
      },
    );

    testWidgets('sin tocar el precio de venta se reenvia tal cual', (
      tester,
    ) async {
      final api = await _abrir(
        tester,
        producto: Producto.desdeJson(_productoJson(precio: 25.8333333)),
      );

      // El PUT reemplaza el producto: si no viajara, abrir y guardar borraria el precio puesto en la web.
      await _guardar(tester);

      expect(api.actualizado?['precioReferencia'], 25.8333333);
    });

    /*
     * El costo se guarda por unidad base con ocho decimales —S/ 289 el saco de
     * 45.6 kg son 6.33771930 el kilo— y el campo del formulario es lo que se
     * vuelve a enviar: recortarlo a dos decimales cambiaria el costo puesto
     * desde la web solo por haber abierto el producto.
     */
    testWidgets('el costo se reenvia con todos sus decimales', (tester) async {
      final api = await _abrir(
        tester,
        producto: Producto.desdeJson(_productoJson(costo: 6.3377193)),
      );

      // Por caja de 12: 6.3377193 × 12 = 76.05 al centimo.
      expect(tester.widget<TextField>(_campoCosto).controller?.text, '76.05');

      // Lo guardado no se toca: se reenvia con todos sus decimales.
      await _guardar(tester);

      expect(api.actualizado?['costoReferencia'], 6.3377193);
    });

    testWidgets('un costo redondo se muestra sin el .0 de sobra', (
      tester,
    ) async {
      // 289 el litro son 3468 la caja de 12.
      await _abrir(
        tester,
        producto: Producto.desdeJson(_productoJson(costo: 289)),
      );

      expect(tester.widget<TextField>(_campoCosto).controller?.text, '3468');
    });
  });

  group('costo por presentacion', () {
    /*
     * La vuelta tiene que cerrar: se teclea S/ 289 el saco de 45.6 kg, se
     * guarda por kilo y al mostrarlo por saco vuelve 289. Con cuatro decimales
     * en el costo base volvia 288.9991.
     */
    test('S/ 289 el saco de 45.6 kg vuelve 289', () {
      final base = double.parse((289 / 45.6).toStringAsFixed(8));

      expect(costoDePresentacion(base, 45.6), 289);
    });

    test('la caja de 12 a 6.33 el litro cuesta 75.96', () {
      expect(costoDePresentacion(6.33, 12), 75.96);
    });

    test('redondea al centimo y no arrastra basura de coma flotante', () {
      // 0.56 × 50 da 28.000000000000004 en coma flotante.
      expect(costoDePresentacion(0.56, 50), 28);
    });

    test('el costo de una lista sale al centimo', () {
      expect(formatoCosto(6.3377193), '6.34');
      expect(formatoCosto(289), '289.00');
    });

    test('con cuatro decimales solo cuando el centimo se come el numero', () {
      // El sobre de 30 g sale a S/ 0.0025 el gramo: "0.00" no dice nada.
      expect(formatoCosto(0.0025), '0.0025');
    });
  });
}
