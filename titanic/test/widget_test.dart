import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/core/navegacion/menu.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';
import 'package:titanic/features/auth/vistas/login_pagina.dart';

/// Almacen vacio para las pruebas.
///
/// Sin esto la pantalla usaria el almacen seguro real, que en el entorno de
/// prueba no existe: la lectura queda colgada y el test falla por un
/// temporizador pendiente, no por la pantalla.
class _AlmacenDePrueba extends SesionAlmacen {
  const _AlmacenDePrueba();

  @override
  Future<String?> token() async => null;

  @override
  Future<Map<String, dynamic>?> usuario() async => null;
}

Widget _app(Widget pantalla) => ProviderScope(
  overrides: [
    sesionAlmacenProvider.overrideWithValue(const _AlmacenDePrueba()),
  ],
  child: MaterialApp(theme: Tema.claro(), home: pantalla),
);

void main() {
  testWidgets('el login muestra sus campos y el boton de ingresar', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const LoginPagina()));
    await tester.pumpAndSettle();

    expect(find.text('Usuario, correo o DNI'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('sin datos avisa que faltan el correo y la contrasena', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const LoginPagina()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.text('Ingresa tu usuario, correo o DNI.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
  });

  test('cada vista del menu tiene una ruta valida y sin repetir', () {
    final rutas = <String>{};

    for (final grupo in menuGrupos) {
      expect(
        grupo.items,
        isNotEmpty,
        reason: '${grupo.titulo} no tiene vistas',
      );

      for (final item in grupo.items) {
        expect(item.ruta.startsWith('/'), isTrue);
        expect(
          rutas.add(item.ruta),
          isTrue,
          reason: 'ruta repetida: ${item.ruta}',
        );

        // El menu y el buscador de rutas tienen que coincidir: si no, el drawer
        // marcaria como activa una vista que la ruta no reconoce.
        expect(resolverRuta(item.ruta).item?.id, item.id);
      }
    }
  });
}
