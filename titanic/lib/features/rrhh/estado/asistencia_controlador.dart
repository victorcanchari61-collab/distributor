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

/// Cuantos hay de cada estado en el mes, para las tarjetas de arriba. Con un
/// empleado elegido en el filtro, solo los suyos: igual que la web.
final resumenAsistenciaProvider = FutureProvider.autoDispose<ResumenAsistencia>(
  (ref) {
    final r = rangoDelMes(ref.watch(mesAsistenciaProvider));
    return ref
        .watch(rrhhApiProvider)
        .resumenAsistencia(
          r.desde,
          r.hasta,
          empleadoId: ref.watch(empleadoAsistenciaFiltroProvider),
        );
  },
);

/// Todos los empleados con sus fechas de ingreso y cese: los que trabajaban
/// cada dia, para el calendario y el pase de lista.
final empleadosAsistenciaProvider =
    FutureProvider.autoDispose<List<EmpleadoAsistencia>>(
      (ref) => ref.watch(rrhhApiProvider).empleadosAsistencia(),
    );

/// Si se ve el calendario del mes arriba de la lista.
final verCalendarioAsistenciaProvider = StateProvider.autoDispose<bool>(
  (ref) => true,
);

/// Los dias no laborables, para avisar en el pase de lista.
final feriadosProvider = FutureProvider.autoDispose<List<Feriado>>(
  (ref) => ref.watch(rrhhApiProvider).feriados(),
);

final busquedaAsistenciaProvider = StateProvider.autoDispose((ref) => '');

/// El id del empleado elegido en el filtro. Null es "todos". Es el id y no el
/// nombre: con el se piden al servidor las tarjetas de esa persona.
final empleadoAsistenciaFiltroProvider = StateProvider.autoDispose<int?>(
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
      .where((a) => empleado == null || a.empleadoId == empleado)
      .where((a) => estado == null || a.estado == estado)
      .where((a) => texto.isEmpty || a.buscable.contains(texto))
      .toList();
});

/// Los empleados que aparecen en las marcas del mes, para el filtro: id y
/// nombre, ordenados por nombre.
final empleadosEnAsistenciaProvider =
    Provider.autoDispose<List<({int id, String nombre})>>((ref) {
      final todas =
          ref.watch(asistenciasProvider).valueOrNull ?? const <Asistencia>[];
      final porId = {for (final a in todas) a.empleadoId: a.empleado};
      return [for (final e in porId.entries) (id: e.key, nombre: e.value)]
        ..sort((a, b) => a.nombre.compareTo(b.nombre));
    });
