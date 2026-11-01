import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/red/cliente_api.dart';
import 'package:titanic/core/tema/acento.dart';
import 'package:titanic/features/facturacion/datos/comprobante.dart';
import 'package:titanic/features/facturacion/datos/comprobantes_api.dart';
import 'package:titanic/features/facturacion/estado/comprobantes_controlador.dart';
import 'package:titanic/features/facturacion/vistas/enviar_whatsapp_hoja.dart';

Map<String, dynamic> _json({
  String? clienteTelefono = '987654321',
  String? whatsAppEstado,
}) => {
  'id': 7,
  'tipo': '03',
  'numeroCompleto': 'B001-1',
  'fechaEmision': '2026-10-30T00:00:00',
  'clienteNombre': 'MDO CHIRA PTO 92',
  'clienteDocumento': '90002280',
  'total': 157,
  'estado': 'ACEPTADO',
  'entorno': 'beta',
  'clienteId': 3,
  'clienteTelefono': clienteTelefono,
  'whatsAppEstado': whatsAppEstado,
  'notas': [
    {
      'id': 9,
      'tipo': '07',
      'numeroCompleto': 'BC01-1',
      'estado': 'ACEPTADO',
      'total': 50,
    },
  ],
};

/// API de mentira: no toca la red y anota a qué número se mandó.
class _ApiFalso extends ComprobantesApi {
  _ApiFalso() : super(ClienteApi());

  String? ultimoTelefono;

  @override
  Future<List<Comprobante>> listar(String tipo) async => [
    Comprobante.desdeJson(_json()),
  ];

  @override
  Future<Comprobante> enviarWhatsApp(int id, {String? telefono}) async {
    ultimoTelefono = telefono;
    return Comprobante.desdeJson(
      _json(whatsAppEstado: 'ENCOLADO')
        ..['whatsAppTelefono'] = telefono
        ..['whatsAppEnviadoEn'] = '2026-10-30T15:00:00Z',
    );
  }
}

Future<void> _abrirHoja(
  WidgetTester tester,
  _ApiFalso api,
  Comprobante c,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [comprobantesApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        home: Acento(
          color: const Color(0xFF0F766E),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => abrirEnvioWhatsApp(context, c),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  test('el comprobante se lee del JSON del backend, con sus notas', () {
    final c = Comprobante.desdeJson(_json());

    expect(c.numeroCompleto, 'B001-1');
    expect(c.total, 157.0);
    expect(c.aceptado, isTrue);
    expect(c.esPrueba, isTrue);
    expect(c.clienteTelefono, '987654321');
    expect(c.notas.single.numeroCompleto, 'BC01-1');
    expect(c.buscable, contains('mdo chira'));
  });

  test('cada tipo pide el permiso de su submódulo', () {
    expect(TipoCpe.submodulo(TipoCpe.factura), 'fact.facturas');
    expect(TipoCpe.submodulo(TipoCpe.boleta), 'fact.boletas');
    expect(TipoCpe.submodulo(TipoCpe.notaCredito), 'fact.notascredito');
    expect(TipoCpe.submodulo(TipoCpe.notaDebito), 'fact.notasdebito');
  });

  test('un teléfono sirve con 9 dígitos, sin importar espacios ni guiones', () {
    expect(soloDigitos('+51 987-654-321'), '51987654321');
    expect(telefonoValido('987 654 321'), isTrue);
    expect(telefonoValido('98765'), isFalse);
    expect(telefonoValido(null), isFalse);
  });

  testWidgets(
    '"Enviar documento" muestra el número del cliente y lo manda tal cual',
    (tester) async {
      final api = _ApiFalso();
      await _abrirHoja(tester, api, Comprobante.desdeJson(_json()));

      expect(find.text('Enviar documento'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '987654321',
      );
      expect(find.textContaining('Es el número del cliente'), findsOneWidget);

      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(api.ultimoTelefono, '987654321');
      // El aviso de "enviado" se retira solo; se deja correr para que no quede un timer pendiente.
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets('el número se cambia ahí mismo y el envío va a ese número', (
    tester,
  ) async {
    final api = _ApiFalso();
    await _abrirHoja(tester, api, Comprobante.desdeJson(_json()));

    await tester.enterText(find.byType(TextField), '999111222');
    await tester.pump();

    expect(find.textContaining('Solo para este envío'), findsOneWidget);

    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(api.ultimoTelefono, '999111222');
    // El aviso de "enviado" se retira solo; se deja correr para que no quede un timer pendiente.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets(
    'sin teléfono del cliente avisa y no deja enviar hasta escribir uno',
    (tester) async {
      final api = _ApiFalso();
      await _abrirHoja(
        tester,
        api,
        Comprobante.desdeJson(_json(clienteTelefono: null)),
      );

      expect(find.textContaining('no tiene teléfono guardado'), findsOneWidget);

      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();
      expect(api.ultimoTelefono, isNull);

      await tester.enterText(find.byType(TextField), '987123456');
      await tester.pump();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(api.ultimoTelefono, '987123456');
      // El aviso de "enviado" se retira solo; se deja correr para que no quede un timer pendiente.
      await tester.pump(const Duration(seconds: 6));
    },
  );
}
