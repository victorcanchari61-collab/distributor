import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/tema/acento.dart';
import 'package:titanic/core/tema/colores.dart';

Color? _leido;

Widget _sonda() => Builder(
  builder: (context) {
    _leido = Acento.de(context);
    return const SizedBox.shrink();
  },
);

void main() {
  setUp(() => _leido = null);

  testWidgets('sin nadie que lo declare, el azul de marca', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _sonda()));
    expect(_leido, Colores.marca);
  });

  testWidgets('dentro de un modulo, el color de ese modulo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Acento(color: Colores.modulos['compras']!, child: _sonda())),
    );
    expect(_leido, Colores.modulos['compras']);
  });

  testWidgets('lo que arma Acento.modulo queda POR DEBAJO del acento', (tester) async {
    /*
     * La trampa que costo encontrar: si `Acento.modulo` recibiera un widget ya
     * construido, el context con el que se armo seria ancestro del Acento, y
     * como la busqueda de un InheritedWidget va hacia arriba, un formulario que
     * leyera su propio acento en el build se llevaria el azul de marca. Se veia
     * igual que antes del cambio, asi que no delataba nada.
     */
    await tester.pumpWidget(
      MaterialApp(home: Acento.modulo('inv', (context) => _sonda())),
    );
    expect(_leido, Colores.modulos['inv']);
  });

  testWidgets('el de dentro manda sobre el de fuera', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Acento.modulo(
          'compras',
          (context) => Acento.modulo('finanzas', (context) => _sonda()),
        ),
      ),
    );
    expect(_leido, Colores.modulos['finanzas']);
  });
}
