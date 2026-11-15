import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titanic/compartido/widgets/app_hoja.dart';

/// La altura máxima de las hojas va en el tema de toda la app: si alguna vez da
/// un número inválido, se cae la app entera con la pantalla roja.
void main() {
  /// Lo que da `altoMaximoHoja` en una pantalla de ese tamaño.
  Future<double> altoEn(WidgetTester tester, Size pantalla) async {
    late double alto;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: pantalla,
          padding: const EdgeInsets.only(top: 24),
        ),
        child: Builder(
          builder: (context) {
            alto = altoMaximoHoja(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return alto;
  }

  testWidgets(
    'al arrancar, con la pantalla aún en 0, no da una altura negativa',
    (tester) async {
      final alto = await altoEn(tester, Size.zero);

      expect(alto, greaterThanOrEqualTo(0));
      // Y sirve como tope de unas BoxConstraints sin romperlas: con -56 salía
      // la pantalla roja "BoxConstraints has non-normalized height constraints".
      expect(BoxConstraints(maxHeight: alto).isNormalized, isTrue);
    },
  );

  testWidgets('en un teléfono llega hasta debajo de la barra de arriba', (
    tester,
  ) async {
    expect(await altoEn(tester, const Size(400, 800)), 800 - 24 - kToolbarHeight);
  });

  testWidgets('en una pantalla muy baja no baja de la mitad', (tester) async {
    expect(await altoEn(tester, const Size(800, 100)), 50);
  });
}
