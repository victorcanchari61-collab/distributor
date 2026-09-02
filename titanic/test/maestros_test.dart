import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/compartido/widgets/app_filtros.dart';
import 'package:titanic/compartido/widgets/app_selector.dart';
import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/core/red/cliente_api.dart';
import 'package:titanic/core/red/excepciones.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';
import 'package:titanic/features/maestros/datos/cliente.dart';
import 'package:titanic/features/maestros/datos/maestros_api.dart';
import 'package:titanic/features/maestros/estado/maestros_controlador.dart';
import 'package:titanic/features/maestros/datos/proveedor.dart';

import 'package:titanic/features/maestros/vistas/clientes_pagina.dart';
import 'package:titanic/features/maestros/vistas/proveedores_pagina.dart';

/// Sesion iniciada, para poder pintar pantallas internas.
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

Map<String, dynamic> _cliente({
  required int id,
  required String documento,
  required String nombre,
  bool activo = true,
  String? diaVisita,
  String? ruta,
}) =>
    {
      'id': id,
      'documento': documento,
      'tipoDoc': documento.length == 8 ? 'DNI' : 'CODIGO',
      'nombre': nombre,
      'direccion': 'MDO SAN ANTONIO',
      'distrito': null,
      'telefono': null,
      'email': null,
      'diaVisita': diaVisita,
      'ruta': ruta,
      'mercado': null,
      'activo': activo,
    };

/// API de mentira: no toca la red.
class _ApiFalso extends MaestrosApi {
  _ApiFalso({this.falla = false}) : super(ClienteApi());

  final bool falla;

  /// Lo que se envio en la ultima alta, para comprobar el formulario.
  Map<String, dynamic>? ultimoCreado;

  @override
  Future<List<Cliente>> clientes() async {
    if (falla) throw const ApiExcepcion('sin conexión');

    return [
      _cliente(id: 1, documento: '45871203', nombre: 'ANA LEANDRO', diaVisita: 'MARTES', ruta: '5'),
      _cliente(id: 2, documento: '90007638', nombre: 'D-SOFIA CAYO'),
      _cliente(id: 3, documento: '41203877', nombre: 'PEDRO RETIRADO', activo: false),
    ].map(Cliente.desdeJson).toList();
  }

  /// Ids a los que se les cambio el estado, para comprobar la confirmacion.
  final cambiados = <int>[];

  @override
  Future<Cliente> cambiarEstadoCliente(int id, {required bool activo}) async {
    cambiados.add(id);
    return Cliente.desdeJson(
      _cliente(id: id, documento: '45871203', nombre: 'ANA LEANDRO', activo: activo),
    );
  }

  @override
  Future<List<Proveedor>> proveedores() async {
    if (falla) throw const ApiExcepcion('sin conexión');

    return [
      Proveedor.desdeJson({
        'id': 1,
        'documento': '20512345678',
        'tipoDoc': 'RUC',
        'nombre': 'ALICORP SAA',
        'nombreComercial': 'ALICORP',
        'rubro': 'Fideos y harinas',
        'direccion': null,
        'distrito': null,
        'telefono': null,
        'email': null,
        'activo': true,
      }),
    ];
  }

  @override
  Future<Cliente> crearCliente(Map<String, dynamic> cuerpo) async {
    ultimoCreado = cuerpo;
    return Cliente.desdeJson(_cliente(id: 9, documento: '12345678', nombre: 'NUEVO'));
  }
}

Future<_ApiFalso> _montarClientes(WidgetTester tester, {bool falla = false}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final api = _ApiFalso(falla: falla);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionAlmacenProvider.overrideWithValue(const _AlmacenConSesion()),
        maestrosApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(theme: Tema.claro(), home: const ClientesPagina()),
    ),
  );
  await tester.pumpAndSettle();

  return api;
}

void main() {
  testWidgets('lista los clientes activos y oculta los desactivados', (tester) async {
    await _montarClientes(tester);

    expect(find.text('ANA LEANDRO'), findsOneWidget);
    expect(find.text('D-SOFIA CAYO'), findsOneWidget);

    // El desactivado no sale en la lista normal.
    expect(find.text('PEDRO RETIRADO'), findsNothing);
  });

  testWidgets('el filtro de estado muestra solo los desactivados', (
    tester,
  ) async {
    await _montarClientes(tester);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();

    // El filtro es un select: se abre y se elige la opcion del menu.
    await tester.tap(find.byType(AppSelector<FiltroEstado>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desactivados').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver resultados'));
    await tester.pumpAndSettle();

    expect(find.text('PEDRO RETIRADO'), findsOneWidget);
    expect(find.text('ANA LEANDRO'), findsNothing);
  });

  testWidgets('el icono de filtros lleva la cuenta de los puestos', (
    tester,
  ) async {
    await _montarClientes(tester);

    // El globo va dentro del icono: los indicadores tambien muestran numeros.
    Finder globo(String n) => find.descendant(
      of: find.byType(BotonFiltros),
      matching: find.text(n),
    );

    // Sin filtros no hay globo.
    expect(globo('1'), findsNothing);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppSelector<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Martes').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver resultados'));
    await tester.pumpAndSettle();

    expect(globo('1'), findsOneWidget);
    expect(find.text('ANA LEANDRO'), findsOneWidget);
    expect(find.text('D-SOFIA CAYO'), findsNothing);
  });

  testWidgets('el buscador filtra por nombre y por documento', (tester) async {
    await _montarClientes(tester);

    await tester.enterText(find.byType(TextField).first, 'sofia');
    await tester.pumpAndSettle();

    expect(find.text('D-SOFIA CAYO'), findsOneWidget);
    expect(find.text('ANA LEANDRO'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '45871203');
    await tester.pumpAndSettle();

    expect(find.text('ANA LEANDRO'), findsOneWidget);
  });

  testWidgets('si el API falla, ofrece reintentar en vez de quedarse vacio', (tester) async {
    await _montarClientes(tester, falla: true);

    expect(find.text('No se pudo cargar'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('el formulario exige documento y nombre antes de enviar', (tester) async {
    final api = await _montarClientes(tester);

    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear cliente'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa el documento.'), findsOneWidget);
    expect(find.text('Ingresa el nombre.'), findsOneWidget);

    // No se llamo al API con datos incompletos.
    expect(api.ultimoCreado, isNull);
  });

  testWidgets('un DNI incompleto no pasa la validacion', (tester) async {
    await _montarClientes(tester);

    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '123');
    await tester.tap(find.text('Crear cliente'));
    await tester.pumpAndSettle();

    expect(find.text('Un DNI tiene 8 dígitos.'), findsOneWidget);
  });

  testWidgets('desactivar pide confirmacion y respeta el cancelar', (tester) async {
    final api = await _montarClientes(tester);

    // El icono de desactivar de la primera tarjeta.
    await tester.tap(find.byTooltip('Desactivar').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Desactivar ANA LEANDRO'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Se cancelo: el API no se toco.
    expect(api.cambiados, isEmpty);

    await tester.tap(find.byTooltip('Desactivar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desactivar'));
    await tester.pumpAndSettle();

    expect(api.cambiados, [1]);
  });

  testWidgets('la pantalla de proveedores se arma sin errores', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sesionAlmacenProvider.overrideWithValue(const _AlmacenConSesion()),
          maestrosApiProvider.overrideWithValue(_ApiFalso(falla: true)),
        ],
        child: MaterialApp(theme: Tema.claro(), home: const ProveedoresPagina()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Proveedores'), findsWidgets);
  });
}
