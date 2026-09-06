import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/compartido/widgets/app_campo_busqueda.dart';

class _Bodega {
  const _Bodega(this.nombre, this.mercado);
  final String nombre;
  final String? mercado;
}

const _bodegas = [
  _Bodega('Bodega Rojas', 'Mercado Central'),
  _Bodega('Bodega Quispe', 'Mercado Central'),
  _Bodega('Minimarket Lucero', 'Santa Anita'),
];

Future<void> _montar(WidgetTester tester, {void Function(_Bodega)? onElegir}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppCampoBusqueda<_Bodega>(
          etiqueta: 'Cliente',
          icono: Icons.contacts_outlined,
          pista: 'Escribe el nombre',
          items: _bodegas,
          titulo: (b) => b.nombre,
          subtitulo: (b) => b.mercado ?? '',
          buscable: (b) => '${b.nombre} ${b.mercado}'.toLowerCase(),
          filtros: [FiltroBusqueda<_Bodega>('Mercado', (b) => b.mercado)],
          onElegir: onElegir ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tocar el campo no abre ninguna hoja: se escribe en el sitio', (tester) async {
    await _montar(tester);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // Lo que fallaba antes: el toque tapaba la pantalla con un modal.
    expect(find.text('Bodega Rojas'), findsNothing);
    expect(find.text('3 resultados'), findsNothing);
  });

  testWidgets('al escribir caen las coincidencias debajo', (tester) async {
    _Bodega? elegida;
    await _montar(tester, onElegir: (b) => elegida = b);

    await tester.enterText(find.byType(TextField), 'rojas');
    await tester.pumpAndSettle();

    expect(find.text('Bodega Rojas'), findsOneWidget);
    expect(find.text('Bodega Quispe'), findsNothing);

    await tester.tap(find.text('Bodega Rojas'));
    await tester.pumpAndSettle();

    expect(elegida?.nombre, 'Bodega Rojas');
    // Elegido: la lista se retira y el nombre queda en el campo.
    expect(find.widgetWithText(TextField, 'Bodega Rojas'), findsOneWidget);
  });

  testWidgets('la lupa abre la lista completa, con sus filtros', (tester) async {
    await _montar(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('3 resultados'), findsOneWidget);
    expect(find.text('Minimarket Lucero'), findsOneWidget);

    // Filtrar es de la hoja, no del campo: junto al campo estorbaba.
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets('el campo no lleva boton de filtros', (tester) async {
    await _montar(tester);

    expect(find.byIcon(Icons.tune), findsNothing);
  });

  testWidgets('sin coincidencias lo dice, no se queda en blanco', (tester) async {
    await _montar(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('Nada coincide con lo que escribiste.'), findsOneWidget);
  });
}
