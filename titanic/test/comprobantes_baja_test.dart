import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/red/cliente_api.dart';
import 'package:titanic/core/tema/acento.dart';
import 'package:titanic/features/facturacion/datos/comprobante.dart';
import 'package:titanic/features/facturacion/datos/comprobantes_api.dart';
import 'package:titanic/features/facturacion/estado/comprobantes_controlador.dart';
import 'package:titanic/features/facturacion/vistas/dar_de_baja_hoja.dart';
import 'package:titanic/features/facturacion/vistas/emitir_nota_hoja.dart';

Map<String, dynamic> _json({
  String tipo = '01',
  String estado = 'ACEPTADO',
  String fechaEmision = '2026-11-05T00:00:00',
  String? notaVentaNumero = 'NV-0012',
  bool ventaDirecta = false,
  String? bajaEstado,
  String? bajaMensaje,
  List<Map<String, dynamic>> notas = const [],
}) => {
  'id': 7,
  'tipo': tipo,
  'numeroCompleto': 'F001-12',
  'fechaEmision': fechaEmision,
  'clienteNombre': 'BODEGA EL PROGRESO',
  'clienteDocumento': '20123456789',
  'total': 118,
  'estado': estado,
  'entorno': 'produccion',
  'notaVentaNumero': notaVentaNumero,
  'ventaDirecta': ventaDirecta,
  'bajaEstado': bajaEstado,
  'bajaMotivo': bajaEstado == null ? null : 'Error en los productos',
  'bajaFecha': bajaEstado == null ? null : '2026-11-06T15:00:00Z',
  'bajaMensaje': bajaMensaje,
  'lineas': [
    {
      'descripcion': 'ARROZ 50KG',
      'cantidad': 1,
      'precio': 118,
      'afectoIgv': true,
    },
  ],
  'notas': notas,
};

Comprobante _c({
  String tipo = '01',
  String estado = 'ACEPTADO',
  String fechaEmision = '2026-11-05T00:00:00',
  String? notaVentaNumero = 'NV-0012',
  bool ventaDirecta = false,
  String? bajaEstado,
  String? bajaMensaje,
  List<Map<String, dynamic>> notas = const [],
}) => Comprobante.desdeJson(
  _json(
    tipo: tipo,
    estado: estado,
    fechaEmision: fechaEmision,
    notaVentaNumero: notaVentaNumero,
    ventaDirecta: ventaDirecta,
    bajaEstado: bajaEstado,
    bajaMensaje: bajaMensaje,
    notas: notas,
  ),
);

/// API de mentira: anota el motivo de la baja y responde lo que se le diga.
class _ApiFalso extends ComprobantesApi {
  _ApiFalso({this.respuestaBaja = 'ACEPTADA'}) : super(ClienteApi());

  final String respuestaBaja;
  String? ultimoMotivo;
  int consultas = 0;

  @override
  Future<List<Comprobante>> listar(String tipo) async => [_c()];

  @override
  Future<Comprobante> darDeBaja(int id, String motivo) async {
    ultimoMotivo = motivo;
    return _c(
      estado: respuestaBaja == 'ACEPTADA' ? 'BAJA' : 'ACEPTADO',
      bajaEstado: respuestaBaja,
      bajaMensaje: respuestaBaja == 'RECHAZADA' ? 'SUNAT no la aceptó' : null,
    );
  }

  @override
  Future<Comprobante> consultarBaja(int id) async {
    consultas++;
    return _c(estado: 'BAJA', bajaEstado: 'ACEPTADA');
  }
}

Future<void> _abrir(
  WidgetTester tester,
  _ApiFalso api,
  Future<void> Function(BuildContext) abrir,
) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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
                  onPressed: () => abrir(context),
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
  group('comprobante con baja y venta directa', () {
    test('lee los campos nuevos del backend', () {
      final c = _c(
        estado: 'BAJA',
        ventaDirecta: true,
        notaVentaNumero: null,
        bajaEstado: 'ACEPTADA',
      );

      expect(c.ventaDirecta, isTrue);
      expect(c.notaVentaNumero, isNull);
      expect(c.bajaEstado, EstadoBajaCpe.aceptada);
      expect(c.bajaMotivo, 'Error en los productos');
      expect(c.bajaFecha, isNotNull);
      expect(c.aceptado, isFalse);
    });

    test('sin esos campos el comprobante sigue siendo válido', () {
      final json = _json()
        ..remove('ventaDirecta')
        ..remove('bajaEstado');
      final c = Comprobante.desdeJson(json);

      expect(c.ventaDirecta, isFalse);
      expect(c.bajaEstado, isNull);
    });

    test('el estado BAJA se llama "Dado de baja"', () {
      expect(EstadoCpe.etiqueta(EstadoCpe.baja), 'Dado de baja');
      expect(
        EstadoCpe.ayuda(EstadoCpe.baja),
        'SUNAT aceptó la baja: la factura ya no vale.',
      );
    });

    test('solo una factura aceptada, reciente y sin notas admite la baja', () {
      final hoy = DateTime(2026, 11, 8);

      expect(_c().puedeDarDeBaja(hoy), isTrue);
      // Una boleta no se da de baja.
      expect(_c(tipo: '03').puedeDarDeBaja(hoy), isFalse);
      // Ya dada de baja o rechazada.
      expect(_c(estado: 'BAJA').puedeDarDeBaja(hoy), isFalse);
      expect(_c(estado: 'RECHAZADO').puedeDarDeBaja(hoy), isFalse);
      // Con la baja en trámite se consulta, no se pide otra vez.
      expect(_c(bajaEstado: 'PENDIENTE').puedeDarDeBaja(hoy), isFalse);
      // Una baja rechazada se puede volver a pedir.
      expect(_c(bajaEstado: 'RECHAZADA').puedeDarDeBaja(hoy), isTrue);
    });

    test('la baja vence a los 7 días de emitida', () {
      final hoy = DateTime(2026, 11, 8);

      expect(
        _c(fechaEmision: '2026-11-01T00:00:00').puedeDarDeBaja(hoy),
        isTrue,
      );
      expect(
        _c(fechaEmision: '2026-10-31T00:00:00').puedeDarDeBaja(hoy),
        isFalse,
      );
    });

    test('una nota de crédito aceptada impide la baja, una rechazada no', () {
      final hoy = DateTime(2026, 11, 8);
      Map<String, dynamic> nota(String estado) => {
        'id': 9,
        'tipo': '07',
        'numeroCompleto': 'FC01-1',
        'estado': estado,
        'total': 50,
      };

      expect(_c(notas: [nota('ACEPTADO')]).puedeDarDeBaja(hoy), isFalse);
      expect(_c(notas: [nota('RECHAZADO')]).puedeDarDeBaja(hoy), isTrue);
    });

    test('el aviso de la baja depende de si la venta fue directa', () {
      expect(
        _c(ventaDirecta: true, notaVentaNumero: null).avisoBaja,
        'Si SUNAT la acepta, la factura deja de valer: el stock vuelve al '
        'almacén y deja de contar en los reportes.',
      );
      expect(
        _c().avisoBaja,
        'Si SUNAT la acepta, la venta NV-0012 se anula: el stock vuelve al '
        'almacén y deja de contar en los reportes.',
      );
      expect(
        _c(notaVentaNumero: null).avisoBaja,
        'Si SUNAT la acepta, la factura deja de valer.',
      );
    });

    test('el aviso de la nota de crédito total sigue la misma lógica', () {
      expect(
        _c(ventaDirecta: true, notaVentaNumero: null).avisoNotaTotal,
        'Si SUNAT la acepta y cubre todo lo facturado, el stock vuelve al '
        'almacén y deja de contar en los reportes.',
      );
      expect(
        _c().avisoNotaTotal,
        'Si SUNAT la acepta y cubre todo lo facturado, la venta NV-0012 se '
        'anula: el stock vuelve al almacén y deja de contar en los reportes.',
      );
      expect(_c(notaVentaNumero: null).avisoNotaTotal, isNull);
    });

    test('el mensaje de la baja según lo que respondió SUNAT', () {
      expect(
        mensajeDeBaja(_c(bajaEstado: 'ACEPTADA')).texto,
        'F001-12 dada de baja',
      );
      final pendiente = mensajeDeBaja(_c(bajaEstado: 'PENDIENTE'));
      expect(
        pendiente.texto,
        'SUNAT todavía procesa la baja: consúltala en unos minutos',
      );
      expect(pendiente.esError, isFalse);

      final rechazada = mensajeDeBaja(
        _c(bajaEstado: 'RECHAZADA', bajaMensaje: 'Plazo vencido'),
      );
      expect(rechazada.texto, 'Plazo vencido');
      expect(rechazada.esError, isTrue);
    });
  });

  group('hoja de baja', () {
    testWidgets('muestra el aviso y no deja enviar un motivo de menos de 3', (
      tester,
    ) async {
      final api = _ApiFalso();
      await _abrir(tester, api, (c) => abrirDarDeBaja(c, _c()));

      expect(find.text('Dar de baja F001-12'), findsOneWidget);
      expect(find.textContaining('la venta NV-0012 se anula'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();
      await tester.tap(find.text('Dar de baja').last);
      await tester.pumpAndSettle();

      expect(api.ultimoMotivo, isNull);
    });

    testWidgets(
      'con motivo válido manda la baja y avisa que quedó dada de baja',
      (tester) async {
        final api = _ApiFalso();
        await _abrir(tester, api, (c) => abrirDarDeBaja(c, _c()));

        await tester.enterText(
          find.byType(TextField),
          '  Error en los productos ',
        );
        await tester.pump();
        await tester.tap(find.text('Dar de baja').last);
        await tester.pumpAndSettle();

        expect(api.ultimoMotivo, 'Error en los productos');
        expect(find.text('F001-12 dada de baja'), findsOneWidget);
        await tester.pump(const Duration(seconds: 6));
      },
    );

    testWidgets('si SUNAT la deja pendiente, dice que se consulte después', (
      tester,
    ) async {
      final api = _ApiFalso(respuestaBaja: 'PENDIENTE');
      await _abrir(tester, api, (c) => abrirDarDeBaja(c, _c()));

      await tester.enterText(find.byType(TextField), 'Error de precio');
      await tester.pump();
      await tester.tap(find.text('Dar de baja').last);
      await tester.pumpAndSettle();

      expect(
        find.text('SUNAT todavía procesa la baja: consúltala en unos minutos'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('si SUNAT la rechaza, muestra su mensaje', (tester) async {
      final api = _ApiFalso(respuestaBaja: 'RECHAZADA');
      await _abrir(tester, api, (c) => abrirDarDeBaja(c, _c()));

      await tester.enterText(find.byType(TextField), 'Error de precio');
      await tester.pump();
      await tester.tap(find.text('Dar de baja').last);
      await tester.pumpAndSettle();

      expect(find.text('SUNAT no la aceptó'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('en una factura directa el aviso no nombra ninguna venta', (
      tester,
    ) async {
      await _abrir(
        tester,
        _ApiFalso(),
        (c) => abrirDarDeBaja(c, _c(ventaDirecta: true, notaVentaNumero: null)),
      );

      expect(
        find.textContaining('la factura deja de valer: el stock vuelve'),
        findsOneWidget,
      );
      expect(find.textContaining('NV-'), findsNothing);
    });
  });

  group('hoja de nota de crédito', () {
    testWidgets('anulación avisa que la venta se anula; otro motivo no', (
      tester,
    ) async {
      await _abrir(
        tester,
        _ApiFalso(),
        (c) => abrirEmitirNota(c, _c(), const [TipoCpe.notaCredito]),
      );

      // El motivo inicial es 01 · Anulación de la operación.
      expect(
        find.textContaining(
          'cubre todo lo facturado, la venta NV-0012 se anula',
        ),
        findsOneWidget,
      );

      await tester.tap(find.textContaining('01 · Anulación'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('03 · Corrección').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('cubre todo lo facturado'), findsNothing);
    });

    testWidgets('en una venta directa el aviso no nombra ninguna venta', (
      tester,
    ) async {
      await _abrir(
        tester,
        _ApiFalso(),
        (c) => abrirEmitirNota(
          c,
          _c(ventaDirecta: true, notaVentaNumero: null),
          const [TipoCpe.notaCredito],
        ),
      );

      expect(
        find.textContaining(
          'cubre todo lo facturado, el stock vuelve al almacén',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('NV-'), findsNothing);
    });
  });
}
