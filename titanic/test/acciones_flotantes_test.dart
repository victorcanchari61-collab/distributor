import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titanic/compartido/widgets/app_acciones_flotantes.dart';

Widget _pantalla(List<AccionGlobal> acciones) => MaterialApp(
  home: Scaffold(
    floatingActionButton: AppAccionesFlotantes(acciones: acciones),
  ),
);

void main() {
  testWidgets('con una sola accion es un boton con su etiqueta', (t) async {
    var toques = 0;
    await t.pumpWidget(
      _pantalla([
        AccionGlobal(
          etiqueta: 'Crear',
          icono: Icons.add,
          onTap: () => toques++,
        ),
      ]),
    );

    expect(find.text('Acciones'), findsNothing);
    await t.tap(find.text('Crear'));
    expect(toques, 1);
  });

  testWidgets('con varias abre el abanico, ejecuta la tocada y cierra', (
    t,
  ) async {
    var exportado = false;
    await t.pumpWidget(
      _pantalla([
        AccionGlobal(etiqueta: 'Crear', icono: Icons.add, onTap: () {}),
        AccionGlobal(
          etiqueta: 'Exportar',
          icono: Icons.description_outlined,
          onTap: () => exportado = true,
        ),
      ]),
    );

    // Cerrado: solo el boton "Acciones".
    expect(find.text('Acciones'), findsOneWidget);
    expect(find.text('Exportar'), findsNothing);

    await t.tap(find.text('Acciones'));
    await t.pumpAndSettle();
    expect(find.text('Crear'), findsOneWidget);
    expect(find.text('Exportar'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await t.tap(find.text('Exportar'));
    await t.pumpAndSettle();
    expect(exportado, isTrue);
    expect(find.text('Exportar'), findsNothing);
  });

  testWidgets('tocar fuera cierra el abanico sin ejecutar nada', (t) async {
    var toques = 0;
    await t.pumpWidget(
      _pantalla([
        AccionGlobal(
          etiqueta: 'Crear',
          icono: Icons.add,
          onTap: () => toques++,
        ),
        AccionGlobal(
          etiqueta: 'Exportar',
          icono: Icons.file_download,
          onTap: () => toques++,
        ),
      ]),
    );

    await t.tap(find.text('Acciones'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(20, 100));
    await t.pumpAndSettle();

    expect(find.text('Exportar'), findsNothing);
    expect(toques, 0);
  });

  testWidgets('sin acciones no dibuja nada', (t) async {
    await t.pumpWidget(_pantalla(const []));
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('las acciones van en un cuarto de circulo alrededor del boton', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final iconos = [Icons.add, Icons.upload, Icons.download, Icons.description];
    await t.pumpWidget(
      _pantalla([
        for (final (i, icono) in iconos.indexed)
          AccionGlobal(etiqueta: 'A$i', icono: icono, onTap: () {}),
      ]),
    );
    await t.tap(find.text('Acciones'));
    await t.pumpAndSettle();

    // El centro del boton: 16 de cada borde mas su radio de 36.
    const centro = Offset(360 - 16 - 36, 700 - 16 - 36);
    final puntos = [for (final i in iconos) t.getCenter(find.byIcon(i))];

    // Todas a la misma distancia del boton: sobre el mismo arco.
    final radios = [for (final p in puntos) (centro - p).distance];
    for (final r in radios) {
      expect(r, closeTo(radios.first, 0.5));
    }

    // La primera justo encima y la última justo a la izquierda, a su altura.
    expect(puntos.first.dx, closeTo(centro.dx, 0.5));
    expect(puntos.first.dy, lessThan(centro.dy));
    expect(puntos.last.dy, closeTo(centro.dy, 0.5));
    expect(puntos.last.dx, lessThan(centro.dx));

    // Ninguna se encima con la vecina.
    for (var i = 0; i < puntos.length - 1; i++) {
      expect((puntos[i] - puntos[i + 1]).distance, greaterThan(52));
    }
  });
}
