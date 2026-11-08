import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/core/navegacion/menu.dart';
import 'package:titanic/core/permisos/permisos.dart' show misPermisosProvider;
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';
import 'package:titanic/features/inicio/vistas/inicio_pagina.dart';

/// Sesion ya iniciada, para pintar las pantallas internas.
class _AlmacenConSesion extends SesionAlmacen {
  const _AlmacenConSesion();

  @override
  Future<String?> token() async => 'token-de-prueba';

  @override
  Future<Map<String, dynamic>?> usuario() async => {
    'id': 1,
    'nombre': 'Admin',
    'email': 'admin@distributor.com',
    'rolId': 1,
    'rol': 'Administrador',
    'activo': true,
  };

  @override
  Future<bool> recordar() async => true;
}

Future<void> _montar(
  WidgetTester tester, {
  Size pantalla = const Size(375, 812),
}) async {
  // Tamano de un telefono comun: los desbordamientos aparecen en pantallas
  // angostas, no en la ventana grande del escritorio.
  tester.view.physicalSize = pantalla;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionAlmacenProvider.overrideWithValue(const _AlmacenConSesion()),
        // El menú lateral esconde lo que el rol no puede ver: aquí se ven todas las vistas.
        misPermisosProvider.overrideWith(
          (ref) async => {
            for (final grupo in menuGrupos)
              for (final item in grupo.items) '${item.id}:ver',
          },
        ),
      ],
      child: MaterialApp(theme: Tema.claro(), home: const InicioPagina()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el inicio muestra los modulos sin desbordarse', (tester) async {
    await _montar(tester);

    expect(find.text('Módulos'), findsOneWidget);
    for (final grupo in menuGrupos) {
      expect(
        find.text(grupo.titulo),
        findsWidgets,
        reason: 'falta ${grupo.titulo}',
      );
    }
  });

  testWidgets('el inicio se ve bien tambien en una pantalla angosta', (
    tester,
  ) async {
    // 320 de ancho es lo mas angosto que se ve todavia en telefonos viejos.
    await _montar(tester, pantalla: const Size(320, 640));

    expect(find.text('Módulos'), findsOneWidget);
  });

  testWidgets('el menu lateral abre y lista los modulos, sin datos de usuario', (
    tester,
  ) async {
    await _montar(tester);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsWidgets);

    // Cerrar sesión y el correo del usuario viven en el menú del avatar de la barra superior, no en el menú lateral.
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Cerrar sesión'),
      ),
      findsNothing,
    );
    expect(find.text('admin@distributor.com'), findsNothing);
  });

  testWidgets('al elegir un modulo se despliegan sus vistas', (tester) async {
    await _montar(tester);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // El primer modulo viene desplegado.
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text(menuGrupos.first.items.first.titulo),
      ),
      findsOneWidget,
    );

    // El titulo del modulo esta dos veces en pantalla (tarjeta del inicio y
    // menu), asi que se busca dentro del propio menu.
    final enMenu = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Finanzas'),
    );

    await tester.tap(enMenu);
    await tester.pumpAndSettle();

    // Se despliegan las vistas de Finanzas: su primera vista aparece en el menú.
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Mi Caja')),
      findsOneWidget,
    );
  });
}
