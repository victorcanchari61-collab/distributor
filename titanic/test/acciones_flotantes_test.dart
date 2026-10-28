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
}
