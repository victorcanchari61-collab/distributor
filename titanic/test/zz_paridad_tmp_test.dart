import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/compartido/consulta_tabla.dart';
import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/core/permisos/permisos.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';
import 'package:titanic/features/config/datos/auditoria.dart';
import 'package:titanic/features/config/estado/auditoria_controlador.dart';
import 'package:titanic/features/config/vistas/auditoria_pagina.dart';
import 'package:titanic/features/finanzas/datos/ganancia.dart';
import 'package:titanic/features/finanzas/estado/ganancia_controlador.dart';
import 'package:titanic/features/finanzas/vistas/mis_ganancias_pagina.dart';
import 'package:titanic/features/inventario/datos/almacen.dart';
import 'package:titanic/features/inventario/datos/motivo.dart';
import 'package:titanic/features/inventario/estado/inventario_controlador.dart';
import 'package:titanic/features/inventario/vistas/ajuste_formulario.dart';

class _Sesion extends SesionAlmacen {
  const _Sesion();

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

class _AuditoriaFalsa extends AuditoriaControlador {
  ConsultaTabla? contada;
  ConsultaTabla? depurada;

  @override
  Future<List<RegistroAuditoria>> build() async => [];

  @override
  Future<int> contar(ConsultaTabla consulta) async {
    contada = consulta;
    return consulta.filtros.isEmpty ? 1234 : 7;
  }

  @override
  Future<int> depurar(ConsultaTabla consulta) async {
    depurada = consulta;
    return 7;
  }
}

Future<void> _montar(
  WidgetTester tester,
  Widget pantalla, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionAlmacenProvider.overrideWithValue(const _Sesion()),
        misPermisosProvider.overrideWith(
          (ref) async => {'config.auditoria:eliminar', 'config.auditoria:ver'},
        ),
        ...overrides,
      ],
      child: MaterialApp(theme: Tema.claro(), home: pantalla),
    ),
  );
  await tester.pumpAndSettle();
}

Motivo _motivo(int id, String nombre, String tipo, {bool pideCosto = false}) => Motivo(
  id: id,
  codigo: 'M$id',
  nombre: nombre,
  tipo: tipo,
  delSistema: false,
  pideCosto: pideCosto,
  activo: true,
  movimientos: 0,
);

void main() {
  testWidgets('ajuste: tipo antes del motivo, motivo por tipo', (tester) async {
    await _montar(
      tester,
      const AjusteFormulario(),
      overrides: [
        motivosDisponiblesProvider.overrideWithValue([
          _motivo(1, 'Carga inicial', 'ENTRADA', pideCosto: true),
          _motivo(2, 'Sobrante', 'ENTRADA', pideCosto: true),
          _motivo(3, 'Merma', 'SALIDA'),
          _motivo(4, 'Faltante', 'SALIDA'),
        ]),
        almacenesActivosProvider.overrideWithValue(const <Almacen>[]),
      ],
    );

    // Por defecto: Ingreso con su primer motivo.
    expect(find.text('Ingreso (suma stock)'), findsOneWidget);
    expect(find.text('Carga inicial'), findsOneWidget);
    // Un ingreso pide costo: aparece el flete.
    expect(find.text('Flete (opcional)'), findsOneWidget);

    // Cambia a Salida: el motivo se reinicia al primero de las salidas.
    await tester.tap(find.text('Ingreso (suma stock)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salida (resta stock)').last);
    await tester.pumpAndSettle();

    expect(find.text('Merma'), findsOneWidget);
    expect(find.text('Carga inicial'), findsNothing);
    // Una salida no pide costo: no hay flete.
    expect(find.text('Flete (opcional)'), findsNothing);

    // El motivo solo lista los de ese tipo.
    await tester.tap(find.text('Merma'));
    await tester.pumpAndSettle();
    expect(find.text('Faltante'), findsWidgets);
    expect(find.text('Sobrante'), findsNothing);
  });

  testWidgets('ganancias: tarjetas, filtros y detalle', (tester) async {
    final pagina = GananciaPagina(
      total: 2,
      resumen: GananciaResumen.desdeJson({
        'desde': '2026-09-01T00:00:00',
        'hasta': '2026-09-19T00:00:00',
        'soloPropio': true,
        'ventas': 5,
        'productos': 2,
        'importe': 1500.5,
        'costo': 1000.25,
        'ganancia': 500.25,
        'margen': 33.3,
        'lineasSinCosto': 1,
      }),
      opciones: const GananciaOpciones(
        vendedores: ['Ana', 'Luis'],
        categorias: ['Abarrotes'],
        marcas: ['Alicorp'],
        productos: ['Arroz 50kg', 'Aceite 1L'],
        ventas: ['NV-0001', 'NV-0002'],
      ),
      items: [
        GananciaProducto.desdeJson({
          'productoId': 1,
          'codigo': 'ARR-50',
          'producto': 'Arroz 50kg',
          'categoria': 'Abarrotes',
          'marca': 'Costeño',
          'cantidad': 12.5,
          'unidadBase': 'Saco',
          'ventas': 3,
          'notas': ['NV-0001', 'NV-0002', 'NV-0003'],
          'vendedores': ['Ana', 'Luis'],
          'ultimaVenta': '2026-09-15T00:00:00',
          'importe': 1000,
          'costo': 700,
          'ganancia': 300,
          'margen': 30.0,
          'sinCosto': false,
        }),
        GananciaProducto.desdeJson({
          'productoId': 2,
          'codigo': 'ACE-1',
          'producto': 'Aceite 1L',
          'categoria': 'Abarrotes',
          'marca': 'Primor',
          'cantidad': 4,
          'unidadBase': 'Botella',
          'ventas': 1,
          'notas': ['NV-0004'],
          'vendedores': ['Ana'],
          'ultimaVenta': '2026-09-10T00:00:00',
          'importe': 500.5,
          'costo': 300.25,
          'ganancia': -20,
          'margen': null,
          'sinCosto': true,
        }),
      ],
    );

    await _montar(
      tester,
      const MisGananciasPagina(),
      overrides: [gananciasProvider.overrideWith((ref) async => pagina)],
    );

    expect(find.text('Arroz 50kg'), findsOneWidget);
    expect(find.text('Aceite 1L'), findsOneWidget);
    expect(find.text('Sin costo'), findsOneWidget);
    expect(find.text('S/ 1500.50'), findsOneWidget);
    expect(find.textContaining('Este mes: 01/09/2026'), findsOneWidget);
    expect(find.textContaining('1 producto vendido no tiene'), findsOneWidget);

    // Filtros de lista con lo que devolvió el servidor.
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Vendedor'), findsOneWidget);
    expect(find.text('Categoría'), findsOneWidget);
    expect(find.text('Marca'), findsOneWidget);
    expect(find.text('Venta'), findsOneWidget);
    expect(find.text('Producto'), findsOneWidget);
    await tester.tap(find.text('Ver resultados'));
    await tester.pumpAndSettle();

    // Detalle con todo, sin cortar las ventas.
    await tester.tap(find.text('Arroz 50kg'));
    await tester.pumpAndSettle();
    expect(find.text('NV-0001, NV-0002, NV-0003'), findsOneWidget);
    expect(find.text('15/09/2026'), findsOneWidget);
  });

  testWidgets('auditoria: depurar con y sin filtros', (tester) async {
    final falsa = _AuditoriaFalsa();

    await _montar(
      tester,
      const AuditoriaPagina(),
      overrides: [
        auditoriaProvider.overrideWith(() => falsa),
        resumenAuditoriaProvider.overrideWith(
          (ref) async => const ResumenAuditoria(
            total: 1234,
            creados: 1,
            actualizados: 2,
            eliminados: 3,
            entidades: ['Producto', 'Cliente'],
            usuarios: ['Ana', 'Luis'],
          ),
        ),
      ],
    );

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Depurar auditoría'), findsOneWidget);
    expect(find.textContaining('1,234 registros'), findsWidgets);
    expect(find.textContaining('No hay ningún filtro'), findsOneWidget);

    // Sin filtros el botón espera la palabra de confirmación.
    FilledButton boton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Eliminar 1,234 registros'));
    expect(boton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'eliminar');
    await tester.pumpAndSettle();
    expect(boton().onPressed, isNotNull);

    // Con un filtro ya no hace falta escribir nada, y se vuelve a contar.
    await tester.tap(find.text('Todas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminados').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('No hay ningún filtro'), findsNothing);
    expect(falsa.contada!.filtros.single.columna, 'accion');
    expect(find.textContaining('7 registros'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar 7 registros'));
    await tester.pumpAndSettle();

    expect(falsa.depurada!.filtros.single.valor, 'ELIMINADO');
    expect(find.text('Depurar auditoría'), findsNothing);
    expect(find.text('Se eliminaron 7 registros'), findsOneWidget);
    // El aviso se cierra solo a los 3 s.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('ganancias: encabezado completo en pantalla chica', (tester) async {
    final pagina = GananciaPagina(
      total: 300,
      resumen: GananciaResumen.desdeJson({
        'desde': '2026-09-01T00:00:00',
        'hasta': '2026-09-19T00:00:00',
        'soloPropio': false,
        'ventas': 5,
        'productos': 300,
        'importe': 1500.5,
        'costo': 1000.25,
        'ganancia': 500.25,
        'margen': 33.3,
        'lineasSinCosto': 12,
      }),
      opciones: const GananciaOpciones(),
      items: [
        for (var i = 0; i < 10; i++)
          GananciaProducto.desdeJson({
            'productoId': i,
            'codigo': 'P-$i',
            'producto': 'Producto largo numero $i con nombre muy extenso para probar',
            'categoria': 'Abarrotes',
            'marca': 'X',
            'cantidad': 1,
            'unidadBase': 'Und',
            'ventas': 1,
            'notas': ['NV-0001'],
            'vendedores': ['Ana'],
            'ultimaVenta': '2026-09-15T00:00:00',
            'importe': 10,
            'costo': 7,
            'ganancia': 3,
            'margen': 30.0,
            'sinCosto': false,
          }),
      ],
    );

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sesionAlmacenProvider.overrideWithValue(const _Sesion()),
          gananciasProvider.overrideWith((ref) async => pagina),
        ],
        child: MaterialApp(theme: Tema.claro(), home: const MisGananciasPagina()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Se muestran los 10 productos'), findsOneWidget);
    expect(find.textContaining('12 productos vendidos no tienen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
