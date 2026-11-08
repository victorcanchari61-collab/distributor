import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titanic/compartido/catalogo_listo.dart';
import 'package:titanic/compartido/widgets/app_acciones_flotantes.dart';
import 'package:titanic/compartido/widgets/app_boton.dart';
import 'package:titanic/compartido/widgets/app_sin_permiso.dart';
import 'package:titanic/core/permisos/sin_permiso.dart';
import 'package:titanic/core/red/apoyo.dart';
import 'package:titanic/core/red/excepciones.dart';
import 'package:titanic/core/tema/colores.dart';

Widget _app(Widget hijo) => MaterialApp(
  home: Scaffold(body: Center(child: hijo)),
);

/// Deja correr el aviso (dura unos segundos) para que no quede un timer vivo.
Future<void> _drenar(WidgetTester t) => t.pump(const Duration(seconds: 8));

const _e403 = ApiExcepcion('No tienes permiso', codigo: 403);
const _e500 = ApiExcepcion('Fallo del servidor', codigo: 500);

void main() {
  group('marca de falta de permiso', () {
    test('permitir devuelve la accion con permiso y la marca sin el', () {
      void hacer() {}
      expect(permitir(true, hacer), same(hacer));
      expect(esSinPermiso(permitir(false, hacer)), isTrue);
      expect(esSinPermiso(hacer), isFalse);
      expect(esSinPermiso(null), isFalse);
    });
  });

  group('AppBoton sin permiso', () {
    testWidgets('con permiso funciona como siempre', (t) async {
      var toques = 0;
      await t.pumpWidget(
        _app(AppBoton(texto: 'Guardar', onPressed: () => toques++)),
      );
      await t.tap(find.text('Guardar'));
      expect(toques, 1);
      expect(find.text(avisoSinPermiso), findsNothing);
    });

    testWidgets('sinPermiso no ejecuta la accion y avisa al tocarlo', (
      t,
    ) async {
      var toques = 0;
      await t.pumpWidget(
        _app(
          AppBoton(
            texto: 'Guardar',
            sinPermiso: true,
            onPressed: () => toques++,
          ),
        ),
      );
      // Sigue a la vista, no desaparece.
      expect(find.text('Guardar'), findsOneWidget);

      // En gris: ni el color del acento ni el del texto normal.
      final boton = t.widget<FilledButton>(find.byType(FilledButton));
      expect(
        boton.style?.backgroundColor?.resolve({}),
        const Color(0xFFE2E8F0),
      );
      expect(boton.style?.foregroundColor?.resolve({}), Colores.tintaTenue);

      await t.tap(find.text('Guardar'));
      await t.pump();
      expect(toques, 0);
      expect(find.text(avisoSinPermiso), findsOneWidget);
      await _drenar(t);
    });

    testWidgets('la marca accionSinPermiso tambien lo deja en gris', (t) async {
      await t.pumpWidget(
        _app(
          const AppBoton(
            texto: 'Nuevo',
            variante: BotonVariante.secundario,
            onPressed: accionSinPermiso,
          ),
        ),
      );
      await t.tap(find.text('Nuevo'));
      await t.pump();
      expect(find.text(avisoSinPermiso), findsOneWidget);
      await _drenar(t);
    });
  });

  group('AppIconoAccion', () {
    testWidgets('sin accion (null) no dibuja nada: no aplica', (t) async {
      await t.pumpWidget(
        _app(
          const AppIconoAccion(
            icono: Icons.edit,
            tooltip: 'Editar',
            onPressed: null,
          ),
        ),
      );
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('con accion llama y no avisa', (t) async {
      var toques = 0;
      await t.pumpWidget(
        _app(
          AppIconoAccion(
            icono: Icons.edit,
            tooltip: 'Editar',
            onPressed: () => toques++,
          ),
        ),
      );
      await t.tap(find.byIcon(Icons.edit));
      expect(toques, 1);
      expect(find.text(avisoSinPermiso), findsNothing);
    });

    testWidgets('sin permiso se ve en gris, con ayuda y avisa al tocarlo', (
      t,
    ) async {
      var toques = 0;
      await t.pumpWidget(
        _app(
          AppIconoAccion(
            icono: Icons.edit,
            tooltip: 'Editar',
            color: Colors.red,
            onPressed: permitir(false, () => toques++),
          ),
        ),
      );
      final icono = t.widget<Icon>(find.byIcon(Icons.edit));
      expect(icono.color, Colores.tintaTenue);
      expect(
        t.widget<IconButton>(find.byType(IconButton)).tooltip,
        avisoSinPermiso,
      );

      await t.tap(find.byIcon(Icons.edit));
      await t.pump();
      expect(toques, 0);
      expect(find.text(avisoSinPermiso), findsOneWidget);
      await _drenar(t);
    });
  });

  group('acciones de la pantalla', () {
    testWidgets('una sola sin permiso: boton gris que avisa', (t) async {
      var toques = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: AppAccionesFlotantes(
              acciones: [
                AccionGlobal(
                  etiqueta: 'Nuevo',
                  icono: Icons.add,
                  onTap: () => toques++,
                ).permitida(false),
              ],
              colorUnica: Colors.green,
            ),
          ),
        ),
      );
      final fab = t.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.backgroundColor, Colores.tintaTenue);

      await t.tap(find.text('Nuevo'));
      await t.pump();
      expect(toques, 0);
      expect(find.text(avisoSinPermiso), findsOneWidget);
      await _drenar(t);
    });

    testWidgets('en el abanico la accion sin permiso avisa y no se ejecuta', (
      t,
    ) async {
      var crear = 0;
      var exportar = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: AppAccionesFlotantes(
              acciones: [
                AccionGlobal(
                  etiqueta: 'Crear',
                  icono: Icons.add,
                  onTap: () => crear++,
                ),
                AccionGlobal(
                  etiqueta: 'Exportar',
                  icono: Icons.description_outlined,
                  onTap: () => exportar++,
                ).permitida(false),
              ],
            ),
          ),
        ),
      );
      await t.tap(find.text('Acciones'));
      await t.pumpAndSettle();
      // Las dos siguen a la vista.
      expect(find.text('Crear'), findsOneWidget);
      expect(find.text('Exportar'), findsOneWidget);

      await t.tap(find.text('Exportar'));
      await t.pumpAndSettle(const Duration(milliseconds: 100));
      expect(exportar, 0);
      expect(crear, 0);
      expect(find.text(avisoSinPermiso), findsOneWidget);
      await _drenar(t);
    });

    test(
      'permitidas aplica a toda la lista y permitida(true) no cambia nada',
      () {
        final a = AccionGlobal(etiqueta: 'A', icono: Icons.add, onTap: () {});
        expect(a.permitida(true), same(a));
        expect(a.permitida(false).sinPermiso, isTrue);
        expect(a.permitida(false).etiqueta, 'A');
        final lista = [a, a].permitidas(false);
        expect(lista.every((x) => x.sinPermiso), isTrue);
      },
    );
  });

  group('menu de opciones', () {
    testWidgets('la opcion sin permiso sale en gris y entrega la marca', (
      t,
    ) async {
      String? elegido;
      await t.pumpWidget(
        _app(
          PopupMenuButton<String>(
            onSelected: (v) => elegido = v,
            itemBuilder: (_) => [
              itemMenu('xml', 'Descargar XML'),
              itemMenu('baja', 'Dar de baja', permitido: false),
            ],
          ),
        ),
      );
      await t.tap(find.byType(PopupMenuButton<String>));
      await t.pumpAndSettle();

      final baja = t.widget<Text>(find.text('Dar de baja'));
      expect(baja.style?.color, Colores.tintaTenue);
      expect(t.widget<Text>(find.text('Descargar XML')).style, isNull);

      await t.tap(find.text('Dar de baja'));
      await t.pumpAndSettle();
      expect(esValorSinPermiso(elegido), isTrue);
      expect(esValorSinPermiso('baja'), isFalse);
    });
  });

  group('catalogos de apoyo (opcional)', () {
    test('un 403 deja el catalogo vacio', () async {
      final r = await opcional<List<int>>(Future.error(_e403), const []);
      expect(r, isEmpty);
    });

    test('otro error se propaga igual que antes', () async {
      await expectLater(
        opcional<List<int>>(Future.error(_e500), const []),
        throwsA(isA<ApiExcepcion>().having((e) => e.codigo, 'codigo', 500)),
      );
    });

    test('si carga bien devuelve lo cargado', () async {
      expect(await opcional<List<int>>(Future.value([1, 2]), const []), [1, 2]);
    });

    test('AsyncValue: 403 se vuelve vacio; 500 y carga quedan igual', () {
      const vacio = <int>[];
      final sinPermiso = AsyncValue<List<int>>.error(_e403, StackTrace.empty);
      final roto = AsyncValue<List<int>>.error(_e500, StackTrace.empty);
      const cargando = AsyncValue<List<int>>.loading();

      expect(sinPermiso.opcional(vacio).value, isEmpty);
      expect(sinPermiso.opcional(vacio).hasError, isFalse);
      expect(roto.opcional(vacio).hasError, isTrue);
      expect(cargando.opcional(vacio).isLoading, isTrue);
      expect(const AsyncValue.data([3]).opcional(vacio).value, [3]);
    });

    testWidgets('catalogoListo: un 403 devuelve vacio sin avisar de error', (
      t,
    ) async {
      List<int>? r;
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => r = await catalogoListo<int>(
                context,
                Future.error(_e403),
                queEs: 'las rutas',
              ),
              child: const Text('cargar'),
            ),
          ),
        ),
      );
      await t.tap(find.text('cargar'));
      await t.pump();
      expect(r, isEmpty);
      expect(find.textContaining('No pudimos cargar'), findsNothing);
    });

    testWidgets('catalogoListo: otro error si se avisa', (t) async {
      List<int>? r;
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => r = await catalogoListo<int>(
                context,
                Future.error(_e500),
                queEs: 'las rutas',
              ),
              child: const Text('cargar'),
            ),
          ),
        ),
      );
      await t.tap(find.text('cargar'));
      await t.pump();
      expect(r, isEmpty);
      expect(
        find.textContaining('No pudimos cargar las rutas'),
        findsOneWidget,
      );
      await _drenar(t);
    });
  });
}
