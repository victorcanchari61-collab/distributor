import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titanic/compartido/widgets/app_pestanas.dart';

/// Las pestañas de Productos: con la última elegida, la fila no debe quedarse
/// al inicio dejando la activa fuera de la pantalla.
void main() {
  const pestanas = [
    Pestana('productos', 'Productos', icono: Icons.inventory_2_outlined, contador: 257),
    Pestana('categorias', 'Categorías', icono: Icons.category_outlined, contador: 3),
    Pestana('marcas', 'Marcas', icono: Icons.sell_outlined, contador: 46),
    Pestana('unidades', 'Unidades', icono: Icons.straighten, contador: 11),
  ];

  Widget pantalla(String activa, ValueChanged<String> onCambio) => MaterialApp(
    home: Scaffold(
      body: Center(
        // Un teléfono angosto: las cuatro no entran.
        child: SizedBox(
          width: 320,
          child: AppPestanas<String>(pestanas: pestanas, activa: activa, onCambio: onCambio),
        ),
      ),
    ),
  );

  bool seVeEntera(WidgetTester tester, String texto) {
    final caja = tester.getRect(find.text(texto));
    final vista = tester.getRect(find.byType(AppPestanas<String>));
    return caja.left >= vista.left && caja.right <= vista.right;
  }

  testWidgets('al abrir con la última activa, la fila ya la muestra', (tester) async {
    await tester.pumpWidget(pantalla('unidades', (_) {}));
    await tester.pumpAndSettle();

    expect(seVeEntera(tester, 'Unidades'), isTrue);
  });

  testWidgets('al cambiar a la última, la fila se desliza hasta ella', (tester) async {
    final activa = ValueNotifier('productos');
    await tester.pumpWidget(
      ValueListenableBuilder<String>(
        valueListenable: activa,
        builder: (context, valor, _) => pantalla(valor, (v) => activa.value = v),
      ),
    );
    await tester.pumpAndSettle();
    expect(seVeEntera(tester, 'Productos'), isTrue);
    expect(seVeEntera(tester, 'Unidades'), isFalse);

    // La misma fila (no se arma de nuevo) recibe otra activa.
    activa.value = 'unidades';
    await tester.pumpAndSettle();

    expect(seVeEntera(tester, 'Unidades'), isTrue);
  });
}
