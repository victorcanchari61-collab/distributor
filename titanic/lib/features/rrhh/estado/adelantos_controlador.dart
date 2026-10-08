import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/adelanto.dart';
import '../datos/planilla.dart';
import 'asistencia_controlador.dart';

/// Todos los adelantos, del mas nuevo al mas viejo.
final adelantosProvider = FutureProvider.autoDispose<List<Adelanto>>(
  (ref) => ref.watch(rrhhApiProvider).adelantos(),
);

final resumenAdelantosProvider = FutureProvider.autoDispose<ResumenAdelantos>(
  (ref) => ref.watch(rrhhApiProvider).resumenAdelantos(),
);

/// Un adelanto con lo descontado semana por semana.
final adelantoProvider = FutureProvider.autoDispose.family<Adelanto, int>(
  (ref, id) => ref.watch(rrhhApiProvider).adelanto(id),
);

/// A quien se le puede dar uno: con su sueldo y lo que ya debe.
final empleadosAdelantoProvider =
    FutureProvider.autoDispose<List<EmpleadoAdelanto>>(
      (ref) => ref.watch(rrhhApiProvider).empleadosAdelanto(),
    );

/// De que cuentas puede salir la plata.
final cuentasAdelantoProvider = FutureProvider.autoDispose<List<CuentaPago>>(
  (ref) => ref.watch(rrhhApiProvider).cuentasAdelanto(),
);

final busquedaAdelantosProvider = StateProvider.autoDispose((ref) => '');

/// Por defecto los que tienen saldo: es lo que se mira.
final estadoAdelantosFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => EstadoAdelanto.pendiente,
);

final empleadoAdelantosFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosAdelantosActivosProvider = Provider.autoDispose<int>((ref) {
  var n = 0;
  if (ref.watch(estadoAdelantosFiltroProvider) != EstadoAdelanto.pendiente) {
    n++;
  }
  if (ref.watch(empleadoAdelantosFiltroProvider) != null) n++;
  return n;
});

/// Los empleados que aparecen en la lista, para el filtro.
final empleadosEnAdelantosProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(adelantosProvider).valueOrNull ?? const <Adelanto>[];
  return todos.map((a) => a.empleado).toSet().toList()..sort();
});

final adelantosFiltradosProvider = Provider.autoDispose<List<Adelanto>>((ref) {
  final todos = ref.watch(adelantosProvider).valueOrNull ?? const <Adelanto>[];
  final texto = ref.watch(busquedaAdelantosProvider).trim().toLowerCase();
  final estado = ref.watch(estadoAdelantosFiltroProvider);
  final empleado = ref.watch(empleadoAdelantosFiltroProvider);
  return todos
      .where((a) => estado == null || a.estado == estado)
      .where((a) => empleado == null || a.empleado == empleado)
      .where((a) => texto.isEmpty || a.buscable.contains(texto))
      .toList();
});
