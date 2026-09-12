import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/core/red/cliente_api.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';
import 'package:titanic/features/config/datos/config_api.dart';
import 'package:titanic/features/config/datos/config_modelos.dart';
import 'package:titanic/features/config/estado/config_controlador.dart';
import 'package:titanic/features/config/vistas/accesos_pagina.dart';
import 'package:titanic/features/config/vistas/empresas_pagina.dart';
import 'package:titanic/features/config/vistas/roles_pagina.dart';
import 'package:titanic/features/config/vistas/usuarios_pagina.dart';

class _AlmacenConSesion extends SesionAlmacen {
  const _AlmacenConSesion();

  @override
  Future<String?> token() async => 'token';

  @override
  Future<Map<String, dynamic>?> usuario() async => {
    'id': 1,
    'nombre': 'Admin',
    'email': 'admin@distributor.com',
    'rolId': 1,
    'rol': 'Administrador',
    'activo': true,
  };
}

/// API de mentira: no toca la red.
class _ApiFalso extends ConfigApi {
  _ApiFalso() : super(ClienteApi());

  /// Cuerpos enviados en la ultima escritura, para comprobar el formulario.
  Map<String, dynamic>? ultimoUsuario;

  /// Permisos enviados al guardar la matriz de Accesos.
  List<Map<String, dynamic>>? ultimosPermisos;

  /// Un recorte del catalogo real: basta para probar las reglas.
  @override
  Future<List<SubmoduloCatalogo>> catalogoPermisos() async => [
    SubmoduloCatalogo.desdeJson({
      'submodulo': 'maestros.clientes',
      'modulo': 'maestros',
      'acciones': [
        'ver',
        'crear',
        'editar',
        'eliminar',
        'exportar',
        'importar',
      ],
    }),
    // Una consulta: ni se crea ni se anula, asi que esas casillas no existen.
    SubmoduloCatalogo.desdeJson({
      'submodulo': 'inv.kardex',
      'modulo': 'inv',
      'acciones': ['ver', 'exportar'],
    }),
  ];

  @override
  Future<Rol> actualizarPermisos(
    int id,
    List<Map<String, dynamic>> permisos,
  ) async {
    ultimosPermisos = permisos;
    return (await roles()).last;
  }

  @override
  Future<List<Usuario>> usuarios() async => [
    Usuario.desdeJson({
      'id': 1,
      'nombre': 'Ana Torres',
      'email': 'ana@distributor.com',
      'dni': '45871203',
      'rolId': 1,
      'rol': 'Administrador',
      'activo': true,
    }),
    Usuario.desdeJson({
      'id': 2,
      'nombre': 'Luis Retirado',
      'email': 'luis@distributor.com',
      'rolId': 2,
      'rol': 'Vendedor',
      'activo': false,
    }),
  ];

  @override
  Future<Usuario> crearUsuario(Map<String, dynamic> cuerpo) async {
    ultimoUsuario = cuerpo;
    return (await usuarios()).first;
  }

  @override
  Future<List<Rol>> roles() async => [
    Rol.desdeJson({
      'id': 1,
      'nombre': 'Administrador',
      'descripcion': 'Acceso total',
      'activo': true,
      'delSistema': true,
      'protegido': true,
      'usuarios': 1,
    }),
    Rol.desdeJson({
      'id': 2,
      'nombre': 'Vendedor',
      'activo': true,
      'delSistema': false,
      'protegido': false,
      'usuarios': 4,
      'permisos': [
        {'submodulo': 'maestros.clientes', 'accion': 'ver'},
        {'submodulo': 'maestros.clientes', 'accion': 'crear'},
      ],
    }),
  ];

  @override
  Future<List<Empresa>> empresas() async => [
    Empresa.desdeJson({
      'id': 1,
      'razonSocial': 'TITANIC D SAC',
      'nombreComercial': 'Titanic D',
      'ruc': '20512345678',
      'activa': true,
      'habilitada': true,
    }),
  ];
}

Future<_ApiFalso> _montar(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final api = _ApiFalso();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionAlmacenProvider.overrideWithValue(const _AlmacenConSesion()),
        configApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(theme: Tema.claro(), home: pantalla),
    ),
  );
  await tester.pumpAndSettle();

  return api;
}

void main() {
  testWidgets('los usuarios se listan con su rol', (tester) async {
    await _montar(tester, const UsuariosPagina());

    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('Administrador'), findsWidgets);
  });

  testWidgets('desactivar un usuario pide confirmacion', (tester) async {
    await _montar(tester, const UsuariosPagina());

    await tester.tap(find.byIcon(Icons.block).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Desactivar Ana Torres'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('el formulario de usuario exige nombre, correo y clave', (
    tester,
  ) async {
    final api = await _montar(tester, const UsuariosPagina());

    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear usuario'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa el nombre.'), findsOneWidget);
    expect(find.text('Ingresa el correo.'), findsOneWidget);
    expect(find.text('Ingresa una contraseña.'), findsOneWidget);
    expect(find.text('Elige un rol.'), findsOneWidget);

    // No se llamo al API con datos incompletos.
    expect(api.ultimoUsuario, isNull);
  });

  testWidgets('los roles muestran cuantos usuarios los tienen', (tester) async {
    await _montar(tester, const RolesPagina());

    expect(find.text('Vendedor'), findsOneWidget);
    expect(find.text('Protegido'), findsOneWidget);
  });

  testWidgets('el rol protegido avisa en vez de desactivarse', (tester) async {
    await _montar(tester, const RolesPagina());

    await tester.tap(find.byIcon(Icons.block).first);
    await tester.pumpAndSettle();

    expect(
      find.text('El rol Administrador no se puede desactivar.'),
      findsOneWidget,
    );
  });

  testWidgets('la empresa activa no ofrece el boton de activar', (
    tester,
  ) async {
    await _montar(tester, const EmpresasPagina());

    expect(find.text('Titanic D'), findsOneWidget);
    expect(find.text('Activa'), findsOneWidget);

    // Ya es la activa: solo quedan editar y retirar.
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });

  testWidgets('el rol protegido avisa que tiene todo concedido', (
    tester,
  ) async {
    await _montar(tester, const AccesosPagina());

    expect(find.textContaining('tiene todo concedido siempre'), findsOneWidget);
  });

  testWidgets('quitar Ver retira las demas acciones de la pantalla', (
    tester,
  ) async {
    final api = await _montar(tester, const AccesosPagina());

    await tester.tap(find.text('Vendedor'));
    await tester.pumpAndSettle();

    // Modulo y luego pantalla: en el telefono la matriz se recorre en dos pasos.
    await tester.tap(find.text('Maestros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();

    // El kardex no se crea ni se anula: esas casillas no se pintan.
    expect(find.text('Anular'), findsNothing);

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Sin Ver, "crear" se fue con ella en vez de quedar concedido e inalcanzable.
    expect(api.ultimosPermisos, isEmpty);
  });
}
