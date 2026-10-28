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

  testWidgets('las etiquetas no se tapan entre si ni tapan otros iconos', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final iconos = [Icons.add, Icons.upload, Icons.download, Icons.description];
    await t.pumpWidget(
      _pantalla([
        for (final (i, icono) in iconos.indexed)
          AccionGlobal(etiqueta: 'Accion $i', icono: icono, onTap: () {}),
      ]),
    );
    await t.tap(find.text('Acciones'));
    await t.pumpAndSettle();

    final etiquetas = [
      for (var i = 0; i < iconos.length; i++) t.getRect(find.text('Accion $i')),
    ];
    final circulos = [
      for (final i in iconos) t.getRect(find.byIcon(i)).inflate(4),
    ];

    for (var a = 0; a < etiquetas.length; a++) {
      for (var b = 0; b < etiquetas.length; b++) {
        if (a == b) continue;
        expect(
          etiquetas[a].overlaps(etiquetas[b]),
          isFalse,
          reason: 'la etiqueta $a tapa a la $b',
        );
        expect(
          etiquetas[a].overlaps(circulos[b]),
          isFalse,
          reason: 'la etiqueta $a tapa al icono $b',
        );
      }
    }
  });

  testWidgets(
    'una etiqueta larga queda en una sola fila aun en pantalla angosta',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      await t.pumpWidget(
        _pantalla([
          AccionGlobal(etiqueta: 'Nuevo', icono: Icons.add, onTap: () {}),
          AccionGlobal(
            etiqueta: 'Categorización',
            icono: Icons.workspace_premium,
            onTap: () {},
          ),
          AccionGlobal(
            etiqueta: 'Subir clientes',
            icono: Icons.upload,
            onTap: () {},
          ),
          AccionGlobal(
            etiqueta: 'Descargar plantilla',
            icono: Icons.download,
            onTap: () {},
          ),
        ]),
      );
      await t.tap(find.text('Acciones'));
      await t.pumpAndSettle();

      // Una fila de letra de 13: bien por debajo de dos líneas.
      expect(t.getSize(find.text('Descargar plantilla')).height, lessThan(20));
      expect(
        t.getRect(find.text('Descargar plantilla')).left,
        greaterThanOrEqualTo(0),
      );
    },
  );
}
