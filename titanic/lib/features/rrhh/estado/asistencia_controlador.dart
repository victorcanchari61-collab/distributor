import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/asistencia.dart';
import '../datos/rrhh_api.dart';

final rrhhApiProvider = Provider(
  (ref) => RrhhApi(ref.watch(clienteApiProvider)),
);

/// El mes que se mira: el primer dia de ese mes. Empieza en el actual.
final mesAsistenciaProvider = StateProvider.autoDispose<DateTime>((ref) {
  final hoy = DateTime.now();
  return DateTime(hoy.year, hoy.month);
});

/// Primer y ultimo dia del mes elegido.
({DateTime desde, DateTime hasta}) rangoDelMes(DateTime mes) => (
  desde: DateTime(mes.year, mes.month),
  hasta: DateTime(mes.year, mes.month + 1, 0),
);

/// Las marcas del mes, de la mas nueva a la mas vieja.
final asistenciasProvider = FutureProvider.autoDispose<List<Asistencia>>((
  ref,
) async {
  final r = rangoDelMes(ref.watch(mesAsistenciaProvider));
  final lista = await ref.watch(rrhhApiProvider).asistencias(r.desde, r.hasta);
  return [...lista]..sort((a, b) {
    final porFecha = b.fecha.compareTo(a.fecha);
    return porFecha != 0 ? porFecha : a.empleado.compareTo(b.empleado);
  });
});

/// Cuantos hay de cada estado en el mes, para las tarjetas de arriba.
final resumenAsistenciaProvider = FutureProvider.autoDispose<ResumenAsistencia>(
  (ref) {
    final r = rangoDelMes(ref.watch(mesAsistenciaProvider));
    return ref.watch(rrhhApiProvider).resumenAsistencia(r.desde, r.hasta);
  },
);

/// Los dias no laborables, para avisar en el pase de lista.
final feriadosProvider = FutureProvider.autoDispose<List<Feriado>>(
  (ref) => ref.watch(rrhhApiProvider).feriados(),
);

final busquedaAsistenciaProvider = StateProvider.autoDispose((ref) => '');

/// Empleado elegido en el filtro. Null es "todos".
final empleadoAsistenciaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// PRESENTE, TARDANZA... Null es "todos".
final estadoAsistenciaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// Por defecto solo las vigentes: una marca anulada no cuenta y confunde.
enum RegistroAsistencia { activas, anuladas, todas }

final registroAsistenciaFiltroProvider =
    StateProvider.autoDispose<RegistroAsistencia>(
      (ref) => RegistroAsistencia.activas,
    );

final filtrosAsistenciaActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(empleadoAsistenciaFiltroProvider) != null) n++;
  if (ref.watch(estadoAsistenciaFiltroProvider) != null) n++;
  if (ref.watch(registroAsistenciaFiltroProvider) !=
      RegistroAsistencia.activas) {
    n++;
  }
  return n;
});

final asistenciasFiltradasProvider = Provider.autoDispose<List<Asistencia>>((
  ref,
) {
  final todas =
      ref.watch(asistenciasProvider).valueOrNull ?? const <Asistencia>[];
  final texto = ref.watch(busquedaAsistenciaProvider).trim().toLowerCase();
  final empleado = ref.watch(empleadoAsistenciaFiltroProvider);
  final estado = ref.watch(estadoAsistenciaFiltroProvider);
  final registro = ref.watch(registroAsistenciaFiltroProvider);

  return todas
      .where(
        (a) => switch (registro) {
          RegistroAsistencia.activas => !a.anulado,
          RegistroAsistencia.anuladas => a.anulado,
          RegistroAsistencia.todas => true,
        },
      )
      .where((a) => empleado == null || a.empleado == empleado)
      .where((a) => estado == null || a.estado == estado)
      .where((a) => texto.isEmpty || a.buscable.contains(texto))
      .toList();
});

/// Los empleados que aparecen en las marcas del mes, para el filtro.
final empleadosEnAsistenciaProvider = Provider.autoDispose<List<String>>((ref) {
  final todas =
      ref.watch(asistenciasProvider).valueOrNull ?? const <Asistencia>[];
  return todas.map((a) => a.empleado).toSet().toList()..sort();
});
