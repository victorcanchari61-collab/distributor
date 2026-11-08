import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/core/red/cliente_api.dart';
import 'package:titanic/core/red/excepciones.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';
import 'package:titanic/features/maestros/datos/cliente.dart';
import 'package:titanic/features/maestros/datos/maestros_api.dart';
import 'package:titanic/features/maestros/estado/maestros_controlador.dart';
import 'package:titanic/features/maestros/vistas/cliente_formulario.dart';

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

  @override
  Future<bool> recordar() async => true;
}

Map<String, dynamic> _json({
  String documento = '45871203',
  String tipoDoc = 'DNI',
  String? documentoAlterno,
  String? tipoDocAlterno,
}) => {
  'id': 4,
  'documento': documento,
  'tipoDoc': tipoDoc,
  'documentoAlterno': documentoAlterno,
  'tipoDocAlterno': tipoDocAlterno,
  'nombre': 'ANA LEANDRO',
  'activo': true,
};

/// API de mentira: anota lo que se mandó y puede responder con un rechazo del servidor.
class _ApiFalso extends MaestrosApi {
  _ApiFalso({this.rechazo}) : super(ClienteApi());

  final String? rechazo;
  Map<String, dynamic>? ultimoCuerpo;

  @override
  Future<List<Cliente>> clientes({String? para}) async => [];

  @override
  Future<Cliente> crearCliente(Map<String, dynamic> cuerpo) async {
    if (rechazo != null) throw ApiExcepcion(rechazo!);
    ultimoCuerpo = cuerpo;
    return Cliente.desdeJson(_json());
  }

  @override
  Future<Cliente> actualizarCliente(int id, Map<String, dynamic> cuerpo) async {
    ultimoCuerpo = cuerpo;
    return Cliente.desdeJson(_json());
  }
}

Future<_ApiFalso> _montar(
  WidgetTester tester, {
  Cliente? cliente,
  String? rechazo,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final api = _ApiFalso(rechazo: rechazo);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionAlmacenProvider.overrideWithValue(const _AlmacenConSesion()),
        maestrosApiProvider.overrideWithValue(api),
      ],
      // Se abre desde otra ruta: al guardar, el formulario se cierra con pop.
      child: MaterialApp(
        theme: Tema.claro(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ClienteFormulario(cliente: cliente),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return api;
}

Finder get _campoAlterno => find.textContaining('segundo documento');

void main() {
  group('modelo', () {
    test('lee el segundo documento y lo muestra con su tipo', () {
      final c = Cliente.desdeJson(
        _json(documentoAlterno: '10458712039', tipoDocAlterno: 'RUC'),
      );

      expect(c.documentoAlterno, '10458712039');
      expect(c.tipoDocAlterno, 'RUC');
      expect(c.textoDocumentoAlterno, 'RUC 10458712039');
      // Se busca también por el segundo documento.
      expect(c.buscable, contains('10458712039'));
    });

    test('sin segundo documento no hay texto que mostrar', () {
      final c = Cliente.desdeJson(_json());

      expect(c.documentoAlterno, isNull);
      expect(c.textoDocumentoAlterno, isNull);
    });

    test('un RUC principal admite un DNI como segundo documento', () {
      final c = Cliente.desdeJson(
        _json(
          documento: '10458712039',
          tipoDoc: 'RUC',
          documentoAlterno: '45871203',
          tipoDocAlterno: 'DNI',
        ),
      );

      expect(c.textoDocumentoAlterno, 'DNI 45871203');
    });
  });

  group('formulario', () {
    testWidgets('con DNI principal ofrece el RUC como segundo documento', (
      tester,
    ) async {
      await _montar(tester);

      expect(_campoAlterno, findsOneWidget);
      expect(find.textContaining('RUC (segundo documento)'), findsOneWidget);
    });

    testWidgets('con un código interno no se ofrece segundo documento', (
      tester,
    ) async {
      await _montar(
        tester,
        cliente: Cliente.desdeJson(_json(documento: '900', tipoDoc: 'CODIGO')),
      );

      expect(_campoAlterno, findsNothing);
    });

    testWidgets('con RUC principal pide un DNI de 8 dígitos', (tester) async {
      final api = await _montar(
        tester,
        cliente: Cliente.desdeJson(
          _json(documento: '10458712039', tipoDoc: 'RUC'),
        ),
      );

      expect(find.textContaining('DNI (segundo documento)'), findsOneWidget);

      // Segundo campo de texto: documento, segundo documento, nombre...
      await tester.enterText(find.byType(TextField).at(1), '1234');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Un DNI tiene 8 dígitos.'), findsOneWidget);
      expect(api.ultimoCuerpo, isNull);
    });

    testWidgets('un RUC incompleto como segundo documento no pasa', (
      tester,
    ) async {
      final api = await _montar(tester, cliente: Cliente.desdeJson(_json()));

      await tester.enterText(find.byType(TextField).at(1), '1045871');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Un RUC tiene 11 dígitos.'), findsOneWidget);
      expect(api.ultimoCuerpo, isNull);
    });

    testWidgets('el segundo documento viaja al guardar', (tester) async {
      final api = await _montar(tester, cliente: Cliente.desdeJson(_json()));

      await tester.enterText(find.byType(TextField).at(1), '10458712039');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(api.ultimoCuerpo?['documentoAlterno'], '10458712039');
      expect(api.ultimoCuerpo?['tipoDoc'], 'DNI');
      // El aviso de "actualizado" se retira solo.
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('vacío se manda como nulo para que el servidor lo borre', (
      tester,
    ) async {
      final api = await _montar(
        tester,
        cliente: Cliente.desdeJson(
          _json(documentoAlterno: '10458712039', tipoDocAlterno: 'RUC'),
        ),
      );

      // Precargado con el que ya tenía.
      expect(find.text('10458712039'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(api.ultimoCuerpo, contains('documentoAlterno'));
      expect(api.ultimoCuerpo?['documentoAlterno'], isNull);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('cambiar el tipo del principal borra el segundo documento', (
      tester,
    ) async {
      await _montar(
        tester,
        cliente: Cliente.desdeJson(
          _json(documentoAlterno: '10458712039', tipoDocAlterno: 'RUC'),
        ),
      );
      expect(find.text('10458712039'), findsOneWidget);

      // El selector de tipo: DNI -> RUC.
      await tester.tap(find.text('DNI').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('RUC').last);
      await tester.pumpAndSettle();

      expect(find.text('10458712039'), findsNothing);
      expect(find.textContaining('DNI (segundo documento)'), findsOneWidget);
    });

    testWidgets('si el servidor lo rechaza por repetido, muestra el mensaje', (
      tester,
    ) async {
      await _montar(
        tester,
        rechazo: 'El RUC 10458712039 ya pertenece a otro cliente.',
      );

      await tester.enterText(find.byType(TextField).at(0), '45871203');
      await tester.enterText(find.byType(TextField).at(1), '10458712039');
      await tester.enterText(find.byType(TextField).at(2), 'ANA LEANDRO');
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();

      expect(
        find.text('El RUC 10458712039 ya pertenece a otro cliente.'),
        findsOneWidget,
      );
    });
  });
}
