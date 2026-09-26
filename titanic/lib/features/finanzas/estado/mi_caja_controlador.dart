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

final filtrosMiCajaActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(tipoMiCajaFiltroProvider) != null) n++;
  if (ref.watch(conceptoMiCajaFiltroProvider) != null) n++;
  return n;
});

final movimientosMiCajaFiltradosProvider =
    Provider.autoDispose<List<MovimientoCaja>>((ref) {
      final todos =
          ref.watch(movimientosMiCajaProvider).valueOrNull ??
          const <MovimientoCaja>[];
      final texto = ref.watch(busquedaMiCajaProvider).trim().toLowerCase();
      final tipo = ref.watch(tipoMiCajaFiltroProvider);
      final concepto = ref.watch(conceptoMiCajaFiltroProvider);

      return todos
          .where((m) => tipo == null || m.tipo == tipo)
          .where((m) => concepto == null || m.documentoOrigen == concepto)
          .where((m) => texto.isEmpty || m.buscable.contains(texto))
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
