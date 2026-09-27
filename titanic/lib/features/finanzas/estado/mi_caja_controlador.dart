import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/mi_caja.dart';
import '../datos/mi_caja_api.dart';

final miCajaApiProvider = Provider(
  (ref) => MiCajaApi(ref.watch(clienteApiProvider)),
);

/// La caja propia, con su saldo.
final miCajaProvider = FutureProvider.autoDispose<MiCaja>(
  (ref) => ref.watch(miCajaApiProvider).mia(),
);

/// Las fechas que se miran. Null es "los últimos 30 días", como en la web: el
/// historial de una caja crece todos los días y no se pide entero.
final rangoMiCajaProvider = StateProvider.autoDispose<DateTimeRange?>(
  (ref) => null,
);

/// El rango que de verdad se pide, con el de 30 días resuelto.
DateTimeRange rangoEfectivo(DateTimeRange? rango) {
  if (rango != null) return rango;
  final hoy = DateUtils.dateOnly(DateTime.now());
  return DateTimeRange(start: hoy.subtract(const Duration(days: 29)), end: hoy);
}

String _dia(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Los movimientos de la caja en las fechas elegidas, del más nuevo al más viejo.
final movimientosMiCajaProvider =
    FutureProvider.autoDispose<List<MovimientoCaja>>((ref) async {
      final rango = rangoEfectivo(ref.watch(rangoMiCajaProvider));
      final lista = await ref
          .watch(miCajaApiProvider)
          .movimientos(desde: _dia(rango.start), hasta: _dia(rango.end));
      return [...lista]..sort((a, b) => b.fecha.compareTo(a.fecha));
    });

final busquedaMiCajaProvider = StateProvider.autoDispose((ref) => '');

/// INGRESO o EGRESO. Null es "todos".
final tipoMiCajaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// De donde viene: PAGO_VENTA, CIERRE_CAJA... Null es "todos".
final conceptoMiCajaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// EFECTIVO o DIGITAL (Yape, transferencia). Null es "todos".
final medioMiCajaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosMiCajaActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(tipoMiCajaFiltroProvider) != null) n++;
  if (ref.watch(conceptoMiCajaFiltroProvider) != null) n++;
  if (ref.watch(medioMiCajaFiltroProvider) != null) n++;
  return n;
});

/// El efectivo y lo digital en una sola lista, del mas nuevo al mas viejo.
///
/// Se piden por separado —uno es la caja, el otro los cobros que van al
/// banco— y se juntan aqui: mientras falte alguno se muestra cargando, y si
/// uno falla se ve ese error.
final filasMiCajaProvider = Provider.autoDispose<AsyncValue<List<FilaMiCaja>>>((
  ref,
) {
  final efectivo = ref.watch(movimientosMiCajaProvider);
  final digital = ref.watch(movimientosDigitalesProvider);
  for (final e in [efectivo, digital]) {
    if (e.hasError) {
      return AsyncValue.error(e.error!, e.stackTrace ?? StackTrace.current);
    }
  }
  if (!efectivo.hasValue || !digital.hasValue) {
    return const AsyncValue.loading();
  }
  return AsyncValue.data(
    [
      for (final m in efectivo.value!) FilaMiCaja.efectivo(m),
      for (final d in digital.value!) FilaMiCaja.digital(d),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha)),
  );
});

final filasMiCajaFiltradasProvider = Provider.autoDispose<List<FilaMiCaja>>((
  ref,
) {
  final todas = ref.watch(filasMiCajaProvider).valueOrNull ?? const [];
  final texto = ref.watch(busquedaMiCajaProvider).trim().toLowerCase();
  final tipo = ref.watch(tipoMiCajaFiltroProvider);
  final concepto = ref.watch(conceptoMiCajaFiltroProvider);
  final medio = ref.watch(medioMiCajaFiltroProvider);

  return todas
      .where(
        (f) => tipo == null || (f.esIngreso ? 'INGRESO' : 'EGRESO') == tipo,
      )
      .where((f) => concepto == null || f.concepto == concepto)
      .where(
        (f) =>
            medio == null || (f.esEfectivo ? 'EFECTIVO' : 'DIGITAL') == medio,
      )
      .where((f) => texto.isEmpty || f.buscable.contains(texto))
      .toList();
});

/// Las categorías de un ingreso o de un egreso, para el formulario.
final categoriasMiCajaProvider = FutureProvider.autoDispose
    .family<List<CategoriaMovimiento>, String>(
      (ref, tipo) => ref.watch(miCajaApiProvider).categorias(tipo),
    );

/// A quién se le puede entregar lo contado.
final destinosMiCajaProvider = FutureProvider.autoDispose<List<CuentaDestino>>(
  (ref) => ref.watch(miCajaApiProvider).destinos(),
);

/// Lo que cobro o pago por Yape, Plin o transferencia en las mismas fechas
/// que se miran en el efectivo.
final movimientosDigitalesProvider =
    FutureProvider.autoDispose<List<MovimientoDigital>>((ref) {
      final rango = rangoEfectivo(ref.watch(rangoMiCajaProvider));
      return ref
          .watch(miCajaApiProvider)
          .digitales(desde: _dia(rango.start), hasta: _dia(rango.end));
    });
