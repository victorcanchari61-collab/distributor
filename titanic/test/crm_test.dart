import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/core/permisos/permisos.dart';
import 'package:titanic/core/red/cliente_api.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';
import 'package:titanic/features/crm/datos/crm.dart';
import 'package:titanic/features/crm/datos/crm_api.dart';
import 'package:titanic/features/crm/estado/crm_controlador.dart';
import 'package:titanic/features/crm/vistas/caida_pagina.dart';
import 'package:titanic/features/crm/vistas/crm_comun.dart';
import 'package:titanic/features/crm/vistas/seguimiento_pagina.dart';

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

Map<String, dynamic> _periodo() => {
  'actual': {'desde': '2026-01-01', 'hasta': '2026-10-27'},
  'anterior': {'desde': '2025-01-01', 'hasta': '2025-10-27'},
  'etiqueta': '1 ene - 27 oct 2026',
  'etiquetaAnterior': '1 ene - 27 oct 2025',
};

Map<String, dynamic> _fila(
  int id,
  String nombre,
  String estado,
  double caida,
) => {
  'id': id,
  'codigo': 'CLI0000$id',
  'cliente': nombre,
  'documento': '2060858980$id',
  'telefono': '987654321',
  'vendedor': 'GUSTAVO MIRANDA',
  'mercado': 'Mercado Central',
  'ultimaCompra': '2026-09-25T00:00:00',
  'diasSinCompra': 32,
  'ventaAnterior': 1000.0,
  'ventaActual': 1000.0 * (1 - caida / 100),
  'variacion': -1000.0 * caida / 100,
  'caidaPct': caida,
  'montoRiesgo': 1000.0 * caida / 100,
  'estado': estado,
  'seguimientoVencido': false,
};

Map<String, dynamic> _gestion(int id, {bool programada = true}) => {
  'id': id,
  'clienteId': 1,
  'fecha': '2026-10-20T15:00:00Z',
  'tipoContacto': 'LLAMADA',
  'tipoEtiqueta': 'Llamada',
  'resultado': 'OPORTUNIDAD',
  'resultadoEtiqueta': 'Oportunidad',
  'tono': 'positivo',
  'comentario': 'Dice que compra la próxima semana',
  'registradoPor': 'Admin',
  'proximoSeguimiento': '2026-10-30T15:00:00Z',
  'proximoTipoContacto': 'VISITA',
  'proximaAccion': 'Llevar muestras',
  'seguimientoEstado': programada ? 'PROGRAMADO' : 'CUMPLIDO',
  'vencida': false,
};

/// API de mentira: no toca la red y recuerda lo que le pidieron.
class _ApiFalso extends CrmApi {
  _ApiFalso() : super(ClienteApi());

  EstadoCaida? estadoPedido;
  Map<String, dynamic>? gestionRegistrada;

  @override
  Future<CaidaClientes> caida({
    String? desde,
    String? hasta,
    EstadoCaida? estado,
  }) async {
    estadoPedido = estado;
    return CaidaClientes.desdeJson({
      'periodo': _periodo(),
      'estados': [
        {'estado': 'CRITICO', 'clientes': 1, 'monto': 900.0},
        {'estado': 'RIESGO', 'clientes': 1, 'monto': 400.0},
      ],
      'ventaAnterior': 2000.0,
      'ventaActual': 700.0,
      'soloPropios': false,
      'items': [
        _fila(1, 'BODEGA LA ESPERANZA', 'CRITICO', 90),
        _fila(2, 'ABARROTES LUNA', 'RIESGO', 40),
      ],
    });
  }

  @override
  Future<CatalogoSeguimiento> catalogo() async =>
      CatalogoSeguimiento.desdeJson({
        'resultados': [
          {
            'clave': 'OPORTUNIDAD',
            'etiqueta': 'Oportunidad',
            'tono': 'positivo',
            'cuando': 'Interesado en comprar',
          },
          {
            'clave': 'SIN_RESPUESTA',
            'etiqueta': 'Sin respuesta',
            'tono': 'neutro',
            'cuando': 'No contestó',
          },
        ],
      });

  @override
  Future<FichaCliente> ficha(int id) async => FichaCliente.desdeJson({
    'cliente': {
      'id': id,
      'codigo': 'CLI00006',
      'nombre': 'BODEGA LA ESPERANZA',
      'tipoDoc': 'DNI',
      'documento': '45123405',
      'telefono': '951853775',
      'direccion': 'JR. EJEMPLO 105',
      'activo': true,
      'estado': {'clave': 'RIESGO', 'etiqueta': 'En riesgo'},
    },
    'kpis': {
      'diasSinComprar': 41,
      'ultimaCompra': {
        'id': 9,
        'fecha': '2026-09-16T00:00:00',
        'documento': 'NV-9',
        'monto': 500.0,
      },
      'saldoPorCobrar': 120.0,
    },
    'periodo': {
      'etiqueta': '1 ene - 27 oct 2026',
      'etiquetaAnterior': '1 ene - 27 oct 2025',
      'ventas': 1212.0,
      'compras': 4,
      'ticketPromedio': 303.0,
      'ventasAnterior': 3180.0,
      'variacion': -1968.0,
      'caidaPct': 61.9,
    },
    'productosPrincipales': [
      {'producto': 'ACEITE 1L', 'monto': 800.0, 'porcentaje': 66.0},
    ],
    'meses': [
      for (var i = 0; i < 24; i++)
        {
          'mes': '2025-${(i % 12 + 1).toString().padLeft(2, '0')}-01',
          'importe': 100.0 * i,
        },
    ],
  });

  @override
  Future<GestionesCliente> gestiones(int id) async =>
      GestionesCliente.desdeJson({
        'items': [_gestion(7)],
        'proximaGestion': _gestion(7),
        'totalAnio': 1,
      });

  @override
  Future<Gestion> registrar(int clienteId, Map<String, dynamic> cuerpo) async {
    gestionRegistrada = cuerpo;
    return Gestion.desdeJson(_gestion(8));
  }

  @override
  Future<ComprasCliente> compras(int id) async =>
      ComprasCliente.desdeJson({'ventas': [], 'productos': []});

  @override
  Future<DocumentosCliente> documentos(int id) async =>
      DocumentosCliente.desdeJson({'pedidos': [], 'devoluciones': []});
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
        crmApiProvider.overrideWithValue(api),
        misPermisosProvider.overrideWith(
          (ref) async => {'crm.seguimiento:crear', 'crm.seguimiento:editar'},
        ),
      ],
      child: MaterialApp(theme: Tema.claro(), home: pantalla),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  test(
    'el estado se lee por su clave y lo desconocido queda sin comparación',
    () {
      expect(EstadoCaida.desdeClave('CRITICO'), EstadoCaida.critico);
      expect(EstadoCaida.desdeClave('???'), EstadoCaida.sinBase);
    },
  );

  test('los soles llevan miles, y las variaciones su signo', () {
    expect(soles(1234567), 'S/ 1,234,567');
    expect(soles(-11120), '−S/ 11,120');
    expect(solesConSigno(80), '+S/ 80');
    expect(porcentaje(-83.3), '−83.3 %');
    expect(porcentaje(null), '—');
  });

  testWidgets('Clientes con caída lista a los clientes con su estado', (
    tester,
  ) async {
    await _montar(tester, const CaidaPagina());

    expect(find.text('BODEGA LA ESPERANZA'), findsOneWidget);
    expect(find.text('ABARROTES LUNA'), findsOneWidget);
    expect(find.text('Crítico'), findsWidgets);
    expect(find.text('En riesgo'), findsWidgets);
  });

  testWidgets('tocar la tarjeta de un estado pide solo ese estado', (
    tester,
  ) async {
    final api = await _montar(tester, const CaidaPagina());
    expect(api.estadoPedido, isNull);

    // La tarjeta es la primera con el texto del estado.
    await tester.tap(find.text('Crítico').first);
    await tester.pumpAndSettle();

    expect(api.estadoPedido, EstadoCaida.critico);
  });

  testWidgets('Gestión y seguimiento muestra la ficha y el historial', (
    tester,
  ) async {
    await _montar(
      tester,
      const SeguimientoPagina(clienteId: 6, pestana: 'seguimiento'),
    );

    expect(find.text('BODEGA LA ESPERANZA'), findsOneWidget);
    expect(find.text('Historial de gestiones'), findsOneWidget);
    expect(find.text('Dice que compra la próxima semana'), findsOneWidget);
    // La programada se puede reprogramar y editar.
    expect(find.text('Reprogramar'), findsOneWidget);
  });

  testWidgets(
    'registrar una gestión envía el tipo, el resultado y el comentario',
    (tester) async {
      final api = await _montar(
        tester,
        const SeguimientoPagina(clienteId: 6, pestana: 'seguimiento'),
      );

      // Con una sola acción el botón dice su etiqueta.
      await tester.tap(find.text('Registrar gestión'));
      await tester.pumpAndSettle();

      // El resultado es obligatorio.
      await tester.tap(find.text('Guardar gestión'));
      await tester.pumpAndSettle();
      expect(find.text('Elige el resultado de la gestión.'), findsOneWidget);
      expect(api.gestionRegistrada, isNull);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oportunidad').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Comentario'),
        'Pide cotización',
      );
      await tester.tap(find.text('Guardar gestión'));
      await tester.pumpAndSettle();

      expect(api.gestionRegistrada, {
        'tipoContacto': 'LLAMADA',
        'resultado': 'OPORTUNIDAD',
        'comentario': 'Pide cotización',
      });

      // El aviso de "registrada" se quita solo: se espera a que lo haga.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    },
  );
}
