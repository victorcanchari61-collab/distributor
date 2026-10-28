import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/compartido/widgets/app_hoja.dart';
import 'package:titanic/core/tema/acento.dart';

void main() {
  testWidgets(
    'la hoja lleva la franja del color del modulo con solo el titulo',
    (tester) async {
      const color = Color(0xFFB91C1C);

      await tester.pumpWidget(
        MaterialApp(
          home: Acento(
            color: color,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => mostrarHoja<void>(
                      context,
                      titulo: 'Editar ACEITE BELTRAN',
                      cuerpo: const Text('contenido'),
                      pie: const Text('botones'),
                    ),
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Editar ACEITE BELTRAN'), findsOneWidget);
      expect(find.text('contenido'), findsOneWidget);
      expect(find.text('botones'), findsOneWidget);

      // La franja es del color del modulo, aunque la hoja cuelgue del Navigator.
      final franja = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Editar ACEITE BELTRAN'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((franja.decoration as BoxDecoration).color, color);

      // Sin la manija de arrastre: la franja ocupa su lugar.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
        isNot(true),
      );
    },
  );
}
