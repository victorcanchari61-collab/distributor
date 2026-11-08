import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
import 'package:titanic/features/crm/vistas/vendedores_caida_pagina.dart';
import 'package:titanic/features/dashboard/vistas/zonas_pagina.dart';

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

/// El tramo que devuelve el servidor: del 1 del mes a hoy contra el mismo tramo
/// del mes anterior, o del 1 de enero a hoy contra el año anterior.
Map<String, dynamic> _periodo([CompararCaida comparar = CompararCaida.mes]) =>
    comparar == CompararCaida.anio
    ? {
        'actual': {'desde': '2026-01-01', 'hasta': '2026-11-08'},
        'anterior': {'desde': '2025-01-01', 'hasta': '2025-11-08'},
        'etiqueta': '1 ene - 8 nov 2026',
        'etiquetaAnterior': '1 ene - 8 nov 2025',
      }
    : {
        'actual': {'desde': '2026-11-01', 'hasta': '2026-11-08'},
        'anterior': {'desde': '2026-10-01', 'hasta': '2026-10-08'},
        'etiqueta': '1 - 8 nov 2026',
        'etiquetaAnterior': '1 - 8 oct 2026',
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
  CompararCaida? compararPedido;
  CompararCaida? compararVendedores;
  CompararCaida? compararZonas;
  CompararCaida? compararProductos;
  Map<String, dynamic>? gestionRegistrada;

  @override
  Future<CaidaClientes> caida({
    String? desde,
    String? hasta,
    EstadoCaida? estado,
    CompararCaida comparar = CompararCaida.mes,
  }) async {
    estadoPedido = estado;
    compararPedido = comparar;
    return CaidaClientes.desdeJson({
      'periodo': _periodo(comparar),
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
  Future<QueDejoDeComprar> queDejoDeComprar(
    int clienteId, {
    String? desde,
    String? hasta,
    CompararCaida comparar = CompararCaida.mes,
  }) async {
    compararProductos = comparar;
    return QueDejoDeComprar.desdeJson({
      'cliente': 'BODEGA LA ESPERANZA',
      'periodo': _periodo(comparar),
      'productos': [
        {
          'codigo': 'P1',
          'producto': 'ACEITE 1L',
          'ventaAnterior': 1000.0,
          'ventaActual': 500.0,
          'variacion': -500.0,
          'situacion': 'MENOS',
        },
      ],
    });
  }

  @override
  Future<VendedoresCaida> vendedores({
    String? desde,
    String? hasta,
    CompararCaida comparar = CompararCaida.mes,
  }) async {
    compararVendedores = comparar;
    return VendedoresCaida.desdeJson({
      'periodo': _periodo(comparar),
      'estados': [
        {'estado': 'SIN_BASE', 'clientes': 1, 'monto': 0.0},
      ],
      'items': [
        {
          'usuarioId': 1,
          'vendedor': 'GUSTAVO MIRANDA',
          'ventaAnterior': 1000.0,
          'ventaActual': 500.0,
          'variacion': -500.0,
          'caidaPct': 50.0,
          'estado': 'RIESGO',
          'clientes': 10,
          'clientesEnCaida': 4,
          'clientesCriticos': 1,
          'montoRiesgo': 500.0,
        },
      ],
    });
  }

  @override
  Future<ZonasCaida> zonas({
    String? desde,
    String? hasta,
    required String agrupar,
    CompararCaida comparar = CompararCaida.mes,
  }) async {
    compararZonas = comparar;
    return ZonasCaida.desdeJson({
      'periodo': _periodo(comparar),
      'soloPropios': false,
      'items': [
        {
          'nombre': 'Mercado Central',
          'clientes': 10,
          'conVentas': 8,
          'criticos': 1,
          'enRiesgo': 2,
          'enSeguimiento': 0,
          'ventaAnterior': 1000.0,
          'ventaActual': 600.0,
          'variacion': -400.0,
          'caidaPct': 40.0,
          'ventaPerdida': 400.0,
          'saldoPorCobrar': 0.0,
        },
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

/// Las tarjetas de estado van en una fila que se desliza: la de sin comparación
/// queda fuera de la pantalla y se construye al acercarse.
Future<void> _verTarjeta(WidgetTester tester, String texto) =>
    tester.scrollUntilVisible(
      find.text(texto),
      150,
      scrollable: find
          .descendant(
            of: find.byType(TarjetasEstado),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  test(
    'el estado se lee por su clave y lo desconocido queda sin comparación',
    () {
      expect(EstadoCaida.desdeClave('CRITICO'), EstadoCaida.critico);
      expect(EstadoCaida.desdeClave('???'), EstadoCaida.sinBase);
    },
  );

  test('los tramos de inactividad cortan por días sin comprar', () {
    expect(TramoInactividad.de16a30.incluye(15), isFalse);
    expect(TramoInactividad.de16a30.incluye(16), isTrue);
    expect(TramoInactividad.de31a60.incluye(32), isTrue);
    expect(TramoInactividad.desde61.incluye(400), isTrue);
    // Quien nunca compró no tiene días: no cae en ningún tramo.
    expect(TramoInactividad.desde61.incluye(null), isFalse);
  });

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

  group('comparar con el mes o el año anterior', () {
    test('el API manda comparar y, sin elegir, es el mes', () async {
      final pedidos = <Uri>[];
      final api = CrmApi(
        ClienteApi(
          cliente: MockClient((req) async {
            pedidos.add(req.url);
            return http.Response('{}', 200);
          }),
          sesion: const _AlmacenConSesion(),
        ),
      );

      // Solo importa la query: la respuesta vacía no se puede leer y falla.
      Future<void> pedir(Future<Object?> Function() f) async {
        try {
          await f();
        } catch (_) {}
      }

      await pedir(() => api.caida());
      await pedir(() => api.caida(comparar: CompararCaida.anio));
      await pedir(() => api.queDejoDeComprar(7));
      await pedir(() => api.queDejoDeComprar(7, comparar: CompararCaida.anio));
      await pedir(() => api.vendedores());
      await pedir(() => api.vendedores(comparar: CompararCaida.anio));
      await pedir(() => api.zonas(agrupar: 'mercado'));
      await pedir(
        () => api.zonas(agrupar: 'ruta', comparar: CompararCaida.anio),
      );

      expect(pedidos.map((u) => u.path.split('/api').last), [
        '/crm/caida',
        '/crm/caida',
        '/crm/caida/7/productos',
        '/crm/caida/7/productos',
        '/crm/vendedores',
        '/crm/vendedores',
        '/dashboard/zonas',
        '/dashboard/zonas',
      ]);
      expect(pedidos.map((u) => u.queryParameters['comparar']), [
        'mes',
        'anio',
        'mes',
        'anio',
        'mes',
        'anio',
        'mes',
        'anio',
      ]);
      expect(pedidos.last.queryParameters['agrupar'], 'ruta');
    });

    test('los rótulos de las columnas: años o mes con año', () {
      final mes = PeriodoCaida.desdeJson(_periodo());
      final anio = PeriodoCaida.desdeJson(_periodo(CompararCaida.anio));

      expect(mes.rotulos(CompararCaida.mes), ('oct 2026', 'nov 2026'));
      expect(anio.rotulos(CompararCaida.anio), ('2025', '2026'));
      // Septiembre se abrevia "set", como en el panel web.
      final set = PeriodoCaida.desdeJson({
        ..._periodo(),
        'anterior': {'desde': '2026-09-01', 'hasta': '2026-09-08'},
      });
      expect(set.rotulos(CompararCaida.mes).$1, 'set 2026');
    });

    test('el nombre del tramo anterior sigue a la elección', () {
      expect(CompararCaida.mes.referencia, 'el mes anterior');
      expect(CompararCaida.anio.referencia, 'el año anterior');
      expect(CompararCaida.mes.sinVentas, 'Sin ventas el mes anterior');
      expect(
        EstadoCaida.sinBase.rangoPara(CompararCaida.anio),
        'Sin ventas el año anterior',
      );
      // Los demás estados no cambian con la comparación.
      expect(
        EstadoCaida.critico.rangoPara(CompararCaida.anio),
        EstadoCaida.critico.rango,
      );
    });

    testWidgets('Clientes con caída compara con el mes anterior por defecto', (
      tester,
    ) async {
      final api = await _montar(tester, const CaidaPagina());

      expect(api.compararPedido, CompararCaida.mes);
      await _verTarjeta(tester, 'no compraron el mes anterior');
      expect(find.text('no compraron el mes anterior'), findsOneWidget);
      expect(
        find.textContaining('S/ 700 vendidos y S/ 2,000 el mes anterior.'),
        findsOneWidget,
      );
      expect(find.text('Del 1 del mes a hoy'), findsOneWidget);
    });

    testWidgets('elegir Año anterior en los filtros vuelve a pedir y cambia '
        'los textos', (tester) async {
      final api = await _montar(tester, const CaidaPagina());

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Comparar con'), findsOneWidget);

      await tester.tap(find.text('Mes anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Año anterior').last);
      await tester.pumpAndSettle();

      expect(api.compararPedido, CompararCaida.anio);
      await tester.tap(find.text('Ver resultados'));
      await tester.pumpAndSettle();
      await _verTarjeta(tester, 'no compraron el año anterior');
      expect(find.text('no compraron el año anterior'), findsOneWidget);
      expect(
        find.textContaining('S/ 700 vendidos y S/ 2,000 el año anterior.'),
        findsOneWidget,
      );
    });

    testWidgets('Qué dejó de comprar rotula las columnas con el mes y su año', (
      tester,
    ) async {
      final api = await _montar(tester, const CaidaPagina());

      await tester.tap(find.byTooltip('Qué dejó de comprar').first);
      await tester.pumpAndSettle();

      expect(api.compararProductos, CompararCaida.mes);
      expect(
        find.textContaining('oct 2026 S/ 1,000  ·  nov 2026 S/ 500'),
        findsOneWidget,
      );
    });

    testWidgets('Qué dejó de comprar rotula las columnas con los años si '
        'se compara por año', (tester) async {
      final api = await _montar(tester, const CaidaPagina());

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mes anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Año anterior').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver resultados'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Qué dejó de comprar').first);
      await tester.pumpAndSettle();

      expect(api.compararProductos, CompararCaida.anio);
      expect(
        find.textContaining('2025 S/ 1,000  ·  2026 S/ 500'),
        findsOneWidget,
      );
    });

    testWidgets('Vendedores con caída también deja elegir con qué comparar', (
      tester,
    ) async {
      final api = await _montar(tester, const VendedoresCaidaPagina());

      expect(api.compararVendedores, CompararCaida.mes);
      await _verTarjeta(tester, 'sin ventas el mes anterior');
      expect(find.text('sin ventas el mes anterior'), findsOneWidget);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mes anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Año anterior').last);
      await tester.pumpAndSettle();

      expect(api.compararVendedores, CompararCaida.anio);
      await tester.tap(find.text('Ver resultados'));
      await tester.pumpAndSettle();
      await _verTarjeta(tester, 'sin ventas el año anterior');
      expect(find.text('sin ventas el año anterior'), findsOneWidget);
    });

    testWidgets('Mercados y rutas también deja elegir con qué comparar', (
      tester,
    ) async {
      final api = await _montar(tester, const ZonasPagina());

      expect(api.compararZonas, CompararCaida.mes);
      expect(find.text('S/ 1,000 el mes anterior'), findsOneWidget);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mes anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Año anterior').last);
      await tester.pumpAndSettle();

      expect(api.compararZonas, CompararCaida.anio);
      expect(find.text('S/ 1,000 el año anterior'), findsOneWidget);
    });
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
