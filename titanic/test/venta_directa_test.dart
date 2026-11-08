import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/core/red/cliente_api.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';
import 'package:titanic/features/facturacion/datos/comprobante.dart';
import 'package:titanic/features/facturacion/datos/comprobantes_api.dart';
import 'package:titanic/features/facturacion/estado/comprobantes_controlador.dart';
import 'package:titanic/features/maestros/datos/maestros_api.dart';
import 'package:titanic/features/maestros/estado/maestros_controlador.dart';
import 'package:titanic/features/ventas/vistas/nota_venta_formulario.dart';

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

class _MaestrosFalso extends MaestrosApi {
  _MaestrosFalso() : super(ClienteApi());
}

class _ComprobantesFalso extends ComprobantesApi {
  _ComprobantesFalso() : super(ClienteApi());
}

Future<void> _montar(WidgetTester tester, {String directo = ''}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionAlmacenProvider.overrideWithValue(const _AlmacenConSesion()),
        comprobantesApiProvider.overrideWithValue(_ComprobantesFalso()),
        maestrosApiProvider.overrideWithValue(_MaestrosFalso()),
      ],
      child: MaterialApp(
        theme: Tema.claro(),
        home: NotaVentaFormulario(directo: directo),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('"Nueva factura" fija el tipo: sin selector de comprobante', (
    tester,
  ) async {
    await _montar(tester, directo: TipoCpe.factura);

    expect(find.text('Nueva factura'), findsOneWidget);
    expect(find.text('Registrar y emitir factura'), findsOneWidget);
    expect(find.text('Comprobante'), findsNothing);
  });

  testWidgets('"Nueva boleta" registra y emite una boleta', (tester) async {
    await _montar(tester, directo: TipoCpe.boleta);

    expect(find.text('Nueva boleta'), findsOneWidget);
    expect(find.text('Registrar y emitir boleta'), findsOneWidget);
  });

  testWidgets('la venta normal sigue siendo "Nueva venta"', (tester) async {
    await _montar(tester);

    expect(find.text('Nueva venta'), findsOneWidget);
    expect(find.text('Registrar'), findsOneWidget);
  });
}
