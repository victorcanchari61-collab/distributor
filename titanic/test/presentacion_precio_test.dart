import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/red/cliente_api.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/maestros/datos/catalogo.dart';
import 'package:titanic/features/maestros/datos/maestros_api.dart';
import 'package:titanic/features/maestros/datos/producto.dart';
import 'package:titanic/features/maestros/estado/maestros_controlador.dart';
import 'package:titanic/features/maestros/vistas/producto_formulario.dart';

/// El marcador `precioPorPresentacion` decide en que unidad sale la linea de
/// los PDF de inventario. El endpoint REEMPLAZA cada presentacion con lo que le
/// llega y un campo ausente se guarda apagado: si la app edita un producto y no
/// lo reenvia, borra el que se puso desde la web. Estos tests fijan que viaja.

/// JSON de una presentacion como la devuelve el backend. `precio` null deja el
/// campo fuera, como responderia un servidor anterior al marcador.
Map<String, dynamic> _presJson({
  required int id,
  required String nombre,
  required double factor,
  bool esBase = false,
  bool? precio,
}) => {
  'id': id,
  'unidadId': 1,
  'unidad': 'Unidad',
  'nombre': nombre,
  'factor': factor,
  'esBase': esBase,
  'esCompra': true,
  'esVenta': true,
  'activo': true,
  'precioPorPresentacion': ?precio,
};

/// Un producto con la base, una caja que SALE por presentacion y un saco que no.
Producto _producto() => Producto.desdeJson({
  'id': 5,
  'codigo': 'ACE-01',
  'nombre': 'ACEITE BELTRAN',
  'unidadBaseId': 1,
  'unidadBase': 'UND',
  'presentaciones': [
    _presJson(id: 10, nombre: 'Unidad', factor: 1, esBase: true, precio: false),
    _presJson(id: 11, nombre: 'Caja x12', factor: 12, precio: true),
    _presJson(id: 12, nombre: 'Saco x50', factor: 50, precio: false),
  ],
});

/// API de mentira: guarda lo que el formulario envia, sin tocar la red.
class _ApiFalso extends MaestrosApi {
  _ApiFalso() : super(ClienteApi());

  /// Cuerpos de PUT /producto/presentaciones/{id}, por id de presentacion.
  final actualizadas = <int, Map<String, dynamic>>{};

  /// Cuerpos de POST /producto/{id}/presentaciones.
  final agregadas = <Map<String, dynamic>>[];

  /// Cuerpo de POST /producto.
  Map<String, dynamic>? creado;

  @override
  Future<List<UnidadMedida>> unidades() async => const [
    UnidadMedida(id: 1, codigo: 'UND', nombre: 'Unidad', activo: true),
  ];

  @override
  Future<List<Categoria>> categorias() async => const [];

  @override
  Future<List<Marca>> marcas() async => const [];

  @override
  Future<List<Producto>> productos() async => const [];

  @override
  Future<Producto> actualizarProducto(int id, Map<String, dynamic> cuerpo) async =>
      _producto();

  @override
  Future<Producto> crearProducto(Map<String, dynamic> cuerpo) async {
    creado = cuerpo;
    return _producto();
  }

  @override
  Future<Presentacion> actualizarPresentacion(
    int presentacionId,
    Map<String, dynamic> cuerpo,
  ) async {
    actualizadas[presentacionId] = cuerpo;
    return Presentacion.desdeJson({'id': presentacionId, 'unidadId': 1});
  }

  @override
  Future<Presentacion> agregarPresentacion(
    int productoId,
    Map<String, dynamic> cuerpo,
  ) async {
    agregadas.add(cuerpo);
    return Presentacion.desdeJson({'id': 99, 'unidadId': 1});
  }
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
          MaterialPageRoute(builder: (_) => ProductoFormulario(producto: producto)),
        ),
        child: const Text('Abrir'),
      ),
    ),
  );
}

Future<_ApiFalso> _abrir(WidgetTester tester, {Producto? producto}) async {
  tester.view.physicalSize = const Size(390, 844);
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
Future<void> _guardar(WidgetTester tester) async {
  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

/// El campo de texto `n` de la hoja de presentacion (0 = nombre, 1 = factor).
/// Solo dentro de la hoja: el formulario de abajo tambien tiene campos.
Finder _campoDeLaHoja(int n) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)).at(n);

Finder get _casillaPdf => find.widgetWithText(CheckboxListTile, 'Por presentación (PDF)');

Future<void> _irAPresentaciones(WidgetTester tester, int cuantas) async {
  await tester.tap(find.text('Presentaciones ($cuantas)'));
  await tester.pumpAndSettle();
}

void main() {
  group('Presentacion', () {
    test('parsear con precioPorPresentacion true y volver a serializar lo conserva', () {
      final p = Presentacion.desdeJson(
        _presJson(id: 11, nombre: 'Caja x12', factor: 12, precio: true),
      );

      expect(p.precioPorPresentacion, isTrue);
      expect(p.aJson()['precioPorPresentacion'], isTrue);

      // Ida y vuelta: lo que se serializa es lo que el backend volveria a leer.
      final otra = Presentacion.desdeJson({'id': p.id, ...p.aJson()});
      expect(otra.precioPorPresentacion, isTrue);
    });

    test('sin el campo queda en false y se envia explicito', () {
      final p = Presentacion.desdeJson(
        _presJson(id: 12, nombre: 'Saco x50', factor: 50),
      );

      expect(p.precioPorPresentacion, isFalse);
      // Viaja como false y no como ausente: ausente y false se guardan igual,
      // pero asi el cuerpo no depende de ese detalle del servidor.
      expect(p.aJson(), containsPair('precioPorPresentacion', false));
    });

    test('el resto del cuerpo no cambia', () {
      final p = Presentacion.desdeJson(
        _presJson(id: 11, nombre: 'Caja x12', factor: 12, precio: true),
      );

      expect(p.aJson(), {
        'unidadId': 1,
        'nombre': 'Caja x12',
        'factor': 12.0,
        'esCompra': true,
        'esVenta': true,
        'precioPorPresentacion': true,
        'activo': true,
      });
    });

    test('un producto lo trae en cada una de sus presentaciones', () {
      final marcas = _producto().presentaciones.map((p) => p.precioPorPresentacion);

      expect(marcas, [false, true, false]);
    });
  });

  group('formulario de producto', () {
    testWidgets('guardar sin tocar las presentaciones reenvia el marcador que tenian', (
      tester,
    ) async {
      final api = await _abrir(tester, producto: _producto());

      await _guardar(tester);

      // El caso que borraba el marcador de la web: editar el producto y nada mas.
      expect(api.actualizadas[11]?['precioPorPresentacion'], isTrue);
      expect(api.actualizadas[12]?['precioPorPresentacion'], isFalse);
    });

    testWidgets('la hoja trae la casilla marcada y editar el nombre no la apaga', (
      tester,
    ) async {
      final api = await _abrir(tester, producto: _producto());
      await _irAPresentaciones(tester, 2);

      // Solo la caja se ve marcada en la lista.
      expect(find.text('PDF por presentación'), findsOneWidget);

      await tester.tap(find.byTooltip('Editar').first);
      await tester.pumpAndSettle();

      expect(tester.widget<CheckboxListTile>(_casillaPdf).value, isTrue);
      expect(
        find.textContaining('la línea sale en esta presentación'),
        findsOneWidget,
      );

      await tester.enterText(_campoDeLaHoja(0), 'Caja x24');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.text('Caja x24'), findsOneWidget);
      expect(find.text('PDF por presentación'), findsOneWidget);

      await _guardar(tester);

      expect(api.actualizadas[11]?['nombre'], 'Caja x24');
      expect(api.actualizadas[11]?['precioPorPresentacion'], isTrue);
    });

    testWidgets('se enciende y se apaga desde la hoja', (tester) async {
      final api = await _abrir(tester, producto: _producto());
      await _irAPresentaciones(tester, 2);

      // El saco viene apagado: se enciende.
      await tester.tap(find.byTooltip('Editar').at(1));
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(_casillaPdf).value, isFalse);

      await tester.tap(_casillaPdf);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      // La caja viene encendida: se apaga.
      await tester.tap(find.byTooltip('Editar').first);
      await tester.pumpAndSettle();
      await tester.tap(_casillaPdf);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      await _guardar(tester);

      expect(api.actualizadas[12]?['precioPorPresentacion'], isTrue);
      expect(api.actualizadas[11]?['precioPorPresentacion'], isFalse);
    });

    testWidgets('una presentacion nueva viaja con el marcador que se le puso', (
      tester,
    ) async {
      final api = await _abrir(tester, producto: _producto());
      await _irAPresentaciones(tester, 2);

      await tester.tap(find.text('Agregar presentación'));
      await tester.pumpAndSettle();

      // Con una sola unidad en el catalogo la hoja ya la trae elegida.
      await tester.enterText(_campoDeLaHoja(0), 'Bolsa x6');
      await tester.enterText(_campoDeLaHoja(1), '6');
      await tester.tap(_casillaPdf);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      await _guardar(tester);

      expect(api.agregadas, hasLength(1));
      expect(api.agregadas.single['nombre'], 'Bolsa x6');
      expect(api.agregadas.single['precioPorPresentacion'], isTrue);
    });

    testWidgets('un producto nuevo lo envia en sus presentaciones', (tester) async {
      final api = await _abrir(tester);

      await tester.enterText(find.byType(TextField).at(0), 'ACE-02');
      await tester.enterText(find.byType(TextField).at(1), 'ACEITE NUEVO');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unidad (UND)').last);
      await tester.pumpAndSettle();

      await _irAPresentaciones(tester, 0);
      await tester.tap(find.text('Agregar presentación'));
      await tester.pumpAndSettle();
      await tester.enterText(_campoDeLaHoja(0), 'Caja x12');
      await tester.enterText(_campoDeLaHoja(1), '12');
      await tester.tap(_casillaPdf);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      final presentaciones = api.creado!['presentaciones'] as List;
      expect(presentaciones, hasLength(1));
      expect((presentaciones.single as Map)['precioPorPresentacion'], isTrue);
    });
  });
}
