import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../../dashboard/estado/periodo_tablero.dart';
import '../datos/mi_caja.dart';
import '../datos/tesoreria.dart';
import '../datos/tesoreria_api.dart';

final tesoreriaApiProvider = Provider(
  (ref) => TesoreriaApi(ref.watch(clienteApiProvider)),
);

/// Null es "los ultimos 30 dias", como en la web: estos historiales crecen
/// todos los dias y no se piden enteros.
DateTimeRange rangoOTreinta(DateTimeRange? rango) {
  if (rango != null) return rango;
  final hoy = DateUtils.dateOnly(DateTime.now());
  return DateTimeRange(start: hoy.subtract(const Duration(days: 29)), end: hoy);
}

// ------------------------------------------------------ Kardex del dinero

final rangoMovimientosProvider = StateProvider.autoDispose<DateTimeRange?>(
  (ref) => null,
);

final movimientosDineroProvider =
    FutureProvider.autoDispose<List<MovimientoDinero>>((ref) {
      final r = rangoOTreinta(ref.watch(rangoMovimientosProvider));
      return ref.watch(tesoreriaApiProvider).movimientos(r.start, r.end);
    });

/// Las cajas y bancos activos, para el filtro y el movimiento manual.
final cuentasMovimientoProvider =
    FutureProvider.autoDispose<List<CuentaDestino>>(
      (ref) => ref.watch(tesoreriaApiProvider).cuentasMovimiento(),
    );

final busquedaMovimientosProvider = StateProvider.autoDispose((ref) => '');
final cuentaMovimientosFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final tipoMovimientosFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final origenMovimientosFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// Por defecto solo lo vigente: lo anulado y su reversa no movieron plata.
final verAnuladosMovimientosProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

final filtrosMovimientosActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(cuentaMovimientosFiltroProvider) != null) n++;
  if (ref.watch(tipoMovimientosFiltroProvider) != null) n++;
  if (ref.watch(origenMovimientosFiltroProvider) != null) n++;
  if (ref.watch(verAnuladosMovimientosProvider)) n++;
  return n;
});

final movimientosDineroFiltradosProvider =
    Provider.autoDispose<List<MovimientoDinero>>((ref) {
      final todos =
          ref.watch(movimientosDineroProvider).valueOrNull ??
          const <MovimientoDinero>[];
      final texto = ref.watch(busquedaMovimientosProvider).trim().toLowerCase();
      final cuenta = ref.watch(cuentaMovimientosFiltroProvider);
      final tipo = ref.watch(tipoMovimientosFiltroProvider);
      final origen = ref.watch(origenMovimientosFiltroProvider);
      final anulados = ref.watch(verAnuladosMovimientosProvider);

      return todos
          .where((m) => anulados || m.vigente)
          .where((m) => cuenta == null || m.cuenta == cuenta)
          .where((m) => tipo == null || m.tipo == tipo)
          .where((m) => origen == null || m.origen == origen)
          .where((m) => texto.isEmpty || m.buscable.contains(texto))
          .toList();
    });

/// Las cuentas que aparecen en el rango, para el filtro.
final cuentasEnMovimientosProvider = Provider.autoDispose<List<String>>((ref) {
  final todos =
      ref.watch(movimientosDineroProvider).valueOrNull ??
      const <MovimientoDinero>[];
  return todos.map((m) => m.cuenta).toSet().toList()..sort();
});

// ------------------------------------------------------ Estado de resultados

/// Abre en "Este mes": un estado de resultados se lee por mes.
final periodoResultadosProvider = StateProvider.autoDispose<PeriodoTablero>(
  (ref) => PeriodoTablero.atajos()[2],
);

final estadoResultadosProvider = FutureProvider.autoDispose<EstadoResultados>((
  ref,
) {
  final p = ref.watch(periodoResultadosProvider);
  return ref.watch(tesoreriaApiProvider).estadoResultados(p.desde, p.hasta);
});

// ------------------------------------------------------ Cierres de caja

final rangoCierresProvider = StateProvider.autoDispose<DateTimeRange?>(
  (ref) => null,
);

final cierresCajaProvider = FutureProvider.autoDispose<List<CierreRegistrado>>((
  ref,
) async {
  final r = rangoOTreinta(ref.watch(rangoCierresProvider));
  final lista = await ref.watch(tesoreriaApiProvider).cierres(r.start, r.end);
  return [...lista]..sort((a, b) => b.fecha.compareTo(a.fecha));
});

final busquedaCierresProvider = StateProvider.autoDispose((ref) => '');
final trabajadorCierresFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final resultadoCierresFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// PENDIENTE, DESCONTADO, ANULADO o NINGUNO (sin faltante).
final descuentoCierresFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosCierresActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(trabajadorCierresFiltroProvider) != null) n++;
  if (ref.watch(resultadoCierresFiltroProvider) != null) n++;
  if (ref.watch(descuentoCierresFiltroProvider) != null) n++;
  return n;
});

final cierresFiltradosProvider = Provider.autoDispose<List<CierreRegistrado>>((
  ref,
) {
  final todos =
      ref.watch(cierresCajaProvider).valueOrNull ?? const <CierreRegistrado>[];
  final texto = ref.watch(busquedaCierresProvider).trim().toLowerCase();
  final trabajador = ref.watch(trabajadorCierresFiltroProvider);
  final resultado = ref.watch(resultadoCierresFiltroProvider);
  final descuento = ref.watch(descuentoCierresFiltroProvider);

  return todos
      .where((c) => trabajador == null || c.usuario == trabajador)
      .where((c) => resultado == null || c.resultado == resultado)
      .where(
        (c) =>
            descuento == null || (c.estadoDescuento ?? 'NINGUNO') == descuento,
      )
      .where((c) => texto.isEmpty || c.buscable.contains(texto))
      .toList();
});

final trabajadoresCierresProvider = Provider.autoDispose<List<String>>((ref) {
  final todos =
      ref.watch(cierresCajaProvider).valueOrNull ?? const <CierreRegistrado>[];
  return todos.map((c) => c.usuario).toSet().toList()..sort();
});

// ------------------------------------------------------ Prestamos recibidos

final prestamosRecibidosProvider = FutureProvider.autoDispose<List<Prestamo>>(
  (ref) => ref.watch(tesoreriaApiProvider).prestamos(),
);

final cuentasPrestamoProvider = FutureProvider.autoDispose<List<CuentaDestino>>(
  (ref) => ref.watch(tesoreriaApiProvider).cuentasPrestamo(),
);

final busquedaPrestamosProvider = StateProvider.autoDispose((ref) => '');

/// Por defecto los vigentes: los que todavia se deben.
final estadoPrestamosFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => EstadoPrestamo.vigente,
);

final filtrosPrestamosActivosProvider = Provider.autoDispose(
  (ref) => ref.watch(estadoPrestamosFiltroProvider) == EstadoPrestamo.vigente
      ? 0
      : 1,
);

final prestamosFiltradosProvider = Provider.autoDispose<List<Prestamo>>((ref) {
  final todos =
      ref.watch(prestamosRecibidosProvider).valueOrNull ?? const <Prestamo>[];
  final texto = ref.watch(busquedaPrestamosProvider).trim().toLowerCase();
  final estado = ref.watch(estadoPrestamosFiltroProvider);
  return todos
      .where((p) => estado == null || p.estado == estado)
      .where((p) => texto.isEmpty || p.buscable.contains(texto))
      .toList();
});

// ------------------------------------------------------ Cajas y bancos

final cuentasFinancierasProvider =
    FutureProvider.autoDispose<List<CuentaFinanciera>>(
      (ref) => ref.watch(tesoreriaApiProvider).cuentas(),
    );

/// Mostrar tambien las desactivadas. Por defecto, solo las activas.
final verInactivasCajasProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);
final busquedaCajasProvider = StateProvider.autoDispose((ref) => '');

/// Las cajas de las personas: la Caja General no es de nadie y va en Bancos.
final cajasProvider = Provider.autoDispose<AsyncValue<List<CuentaFinanciera>>>(
  (ref) => ref
      .watch(cuentasFinancierasProvider)
      .whenData(
        (l) => l
            .where(
              (c) => c.naturaleza == 'CAJA' && c.usuarioResponsableId != null,
            )
            .toList(),
      ),
);

final cajasFiltradasProvider = Provider.autoDispose<List<CuentaFinanciera>>((
  ref,
) {
  final todas =
      ref.watch(cajasProvider).valueOrNull ?? const <CuentaFinanciera>[];
  final texto = ref.watch(busquedaCajasProvider).trim().toLowerCase();
  final inactivas = ref.watch(verInactivasCajasProvider);
  return todas
      .where((c) => inactivas || c.activo)
      .where((c) => texto.isEmpty || c.buscable.contains(texto))
      .toList();
});

final verInactivasBancosProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);
final busquedaBancosProvider = StateProvider.autoDispose((ref) => '');

/// Las cuentas bancarias.
final cuentasBancariasProvider =
    Provider.autoDispose<AsyncValue<List<CuentaFinanciera>>>(
      (ref) => ref
          .watch(cuentasFinancierasProvider)
          .whenData((l) => l.where((c) => c.naturaleza == 'BANCO').toList()),
    );

final cuentasBancariasFiltradasProvider =
    Provider.autoDispose<List<CuentaFinanciera>>((ref) {
      final todas =
          ref.watch(cuentasBancariasProvider).valueOrNull ??
          const <CuentaFinanciera>[];
      final texto = ref.watch(busquedaBancosProvider).trim().toLowerCase();
      final inactivas = ref.watch(verInactivasBancosProvider);
      return todas
          .where((c) => inactivas || c.activo)
          .where((c) => texto.isEmpty || c.buscable.contains(texto))
          .toList();
    });

/// El catalogo de bancos, para elegir el de una cuenta.
final bancosCatalogoProvider = FutureProvider.autoDispose<List<Banco>>(
  (ref) => ref.watch(tesoreriaApiProvider).bancos(),
);

/// Los movimientos de una cuenta en los ultimos 30 dias, del mas nuevo al
/// mas viejo.
final movimientosCuentaProvider = FutureProvider.autoDispose
    .family<List<MovimientoCaja>, int>((ref, id) async {
      final r = rangoOTreinta(null);
      final lista = await ref
          .watch(tesoreriaApiProvider)
          .movimientosCuenta(id, r.start, r.end);
      return [...lista]..sort((a, b) => b.fecha.compareTo(a.fecha));
    });

// ------------------------------------------------------ Ingresos y egresos

enum PestanaOperativos { pendientes, recurrentes, categorias }

final pestanaOperativosProvider = StateProvider.autoDispose<PestanaOperativos>(
  (ref) => PestanaOperativos.pendientes,
);

final pendientesProvider = FutureProvider.autoDispose<List<GastoPendiente>>(
  (ref) => ref.watch(tesoreriaApiProvider).pendientes(),
);

final recurrentesProvider = FutureProvider.autoDispose<List<GastoRecurrente>>(
  (ref) => ref.watch(tesoreriaApiProvider).recurrentes(),
);

final categoriasFinanzasProvider =
    FutureProvider.autoDispose<List<CategoriaFinanzas>>(
      (ref) => ref.watch(tesoreriaApiProvider).categorias(),
    );

final busquedaOperativosProvider = StateProvider.autoDispose((ref) => '');

/// INGRESO o EGRESO, solo para las categorias. Null es "todos".
final tipoCategoriasFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// OPERATIVO o NO_OPERATIVO, solo para las categorias. Null es "todos".
final origenCategoriasFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosCategoriasActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(tipoCategoriasFiltroProvider) != null) n++;
  if (ref.watch(origenCategoriasFiltroProvider) != null) n++;
  return n;
});

final categoriasFiltradasProvider =
    Provider.autoDispose<List<CategoriaFinanzas>>((ref) {
      final todas =
          ref.watch(categoriasFinanzasProvider).valueOrNull ??
          const <CategoriaFinanzas>[];
      final texto = ref.watch(busquedaOperativosProvider).trim().toLowerCase();
      final tipo = ref.watch(tipoCategoriasFiltroProvider);
      final origen = ref.watch(origenCategoriasFiltroProvider);
      return todas
          .where((c) => tipo == null || c.tipo == tipo)
          .where((c) => origen == null || c.origen == origen)
          .where((c) => texto.isEmpty || c.buscable.contains(texto))
          .toList();
    });

final recurrentesFiltradosProvider =
    Provider.autoDispose<List<GastoRecurrente>>((ref) {
      final todos =
          ref.watch(recurrentesProvider).valueOrNull ??
          const <GastoRecurrente>[];
      final texto = ref.watch(busquedaOperativosProvider).trim().toLowerCase();
      return todos
          .where((r) => texto.isEmpty || r.buscable.contains(texto))
          .toList();
    });

final pendientesFiltradosProvider = Provider.autoDispose<List<GastoPendiente>>((
  ref,
) {
  final todos =
      ref.watch(pendientesProvider).valueOrNull ?? const <GastoPendiente>[];
  final texto = ref.watch(busquedaOperativosProvider).trim().toLowerCase();
  return todos
      .where((p) => texto.isEmpty || p.buscable.contains(texto))
      .toList()
    ..sort((a, b) => a.proximoVencimiento.compareTo(b.proximoVencimiento));
});
