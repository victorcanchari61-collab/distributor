import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/planilla.dart';
import 'asistencia_controlador.dart';

/// El lunes de la semana de esa fecha: la planilla va de lunes a domingo.
DateTime lunesDe(DateTime fecha) {
  final dia = DateUtils.dateOnly(fecha);
  return dia.subtract(Duration(days: dia.weekday - DateTime.monday));
}

/// El lunes de la semana que se mira. Empieza en la actual.
final semanaPlanillaProvider = StateProvider.autoDispose<DateTime>(
  (ref) => lunesDe(DateTime.now()),
);

/// La planilla de esa semana, o null si todavia no se armo.
final planillaSemanaProvider = FutureProvider.autoDispose<Planilla?>(
  (ref) => ref
      .watch(rrhhApiProvider)
      .planillaSemana(ref.watch(semanaPlanillaProvider)),
);

/// El detalle como lista, para la pantalla: vacio si no hay planilla.
final detallePlanillaProvider =
    Provider.autoDispose<AsyncValue<List<PlanillaDetalle>>>(
      (ref) => ref
          .watch(planillaSemanaProvider)
          .whenData((p) => p?.detalle ?? const <PlanillaDetalle>[]),
    );

final busquedaPlanillaProvider = StateProvider.autoDispose((ref) => '');

final detallePlanillaFiltradoProvider =
    Provider.autoDispose<List<PlanillaDetalle>>((ref) {
      final detalle =
          ref.watch(detallePlanillaProvider).valueOrNull ??
          const <PlanillaDetalle>[];
      final texto = ref.watch(busquedaPlanillaProvider).trim().toLowerCase();
      return detalle
          .where((d) => texto.isEmpty || d.buscable.contains(texto))
          .toList();
    });

/// Todas las semanas armadas, de la mas nueva a la mas vieja.
final historialPlanillasProvider =
    FutureProvider.autoDispose<List<PlanillaResumen>>(
      (ref) => ref.watch(rrhhApiProvider).historialPlanillas(),
    );

/// De que cuentas puede salir el pago.
final cuentasPlanillaProvider = FutureProvider.autoDispose<List<CuentaPago>>(
  (ref) => ref.watch(rrhhApiProvider).cuentasPlanilla(),
);
