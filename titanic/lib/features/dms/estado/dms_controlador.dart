import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/dms_api.dart';
import '../datos/dms_modelos.dart';

final dmsApiProvider = Provider((ref) => DmsApi(ref.watch(clienteApiProvider)));

// --- Visitas ---

DateTime _hoy() {
  final ahora = DateTime.now();
  return DateTime(ahora.year, ahora.month, ahora.day);
}

/// El día que se está mirando. Por defecto hoy: es la lista de trabajo del
/// vendedor, y lo de otros días es consulta.
final diaVisitasProvider = StateProvider.autoDispose<DateTime>((ref) => _hoy());

/// Ruta por la que se filtra, en el servidor. Null es "todas".
final rutaVisitasProvider = StateProvider.autoDispose<int?>((ref) => null);

/// Si se ven todas, solo las pendientes o solo las que ya tienen pedido.
enum FiltroVisita { todas, pendientes, atendidas }

final filtroVisitaProvider = StateProvider.autoDispose(
  (ref) => FiltroVisita.todas,
);

final busquedaVisitasProvider = StateProvider.autoDispose((ref) => '');

/// Vendedor y mercado, en memoria: a diferencia de la ruta, no van al
/// servidor porque el día ya trae pocas filas.
final vendedorVisitasFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final mercadoVisitasFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final visitasProvider = FutureProvider.autoDispose<List<Visita>>((ref) {
  final dia = ref.watch(diaVisitasProvider);
  return ref
      .watch(dmsApiProvider)
      .visitas(desde: dia, hasta: dia, rutaId: ref.watch(rutaVisitasProvider));
});

final resumenVisitasProvider = FutureProvider.autoDispose<ResumenVisitas>((
  ref,
) {
  final dia = ref.watch(diaVisitasProvider);
  return ref
      .watch(dmsApiProvider)
      .resumenVisitas(
        desde: dia,
        hasta: dia,
        rutaId: ref.watch(rutaVisitasProvider),
      );
});

final filtrosVisitasActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(rutaVisitasProvider) != null) n++;
  if (ref.watch(filtroVisitaProvider) != FiltroVisita.todas) n++;
  if (ref.watch(vendedorVisitasFiltroProvider) != null) n++;
  if (ref.watch(mercadoVisitasFiltroProvider) != null) n++;
  return n;
});

/// Lo que se ve, con las pendientes primero.
///
/// Es una lista de trabajo: lo que falta es lo que hay que mirar, y lo ya
/// atendido va abajo como constancia.
final visitasFiltradasProvider = Provider.autoDispose<List<Visita>>((ref) {
  final todas = ref.watch(visitasProvider).valueOrNull ?? const <Visita>[];
  final texto = ref.watch(busquedaVisitasProvider).trim().toLowerCase();
  final filtro = ref.watch(filtroVisitaProvider);
  final vendedor = ref.watch(vendedorVisitasFiltroProvider);
  final mercado = ref.watch(mercadoVisitasFiltroProvider);

  return todas
      .where(
        (v) => switch (filtro) {
          FiltroVisita.todas => true,
          FiltroVisita.pendientes => !v.atendido,
          FiltroVisita.atendidas => v.atendido,
        },
      )
      .where((v) => vendedor == null || v.vendedor == vendedor)
      .where((v) => mercado == null || v.mercado == mercado)
      .where((v) => texto.isEmpty || v.buscable.contains(texto))
      .toList()
    ..sort((a, b) {
      if (a.atendido != b.atendido) return a.atendido ? 1 : -1;
      return a.cliente.compareTo(b.cliente);
    });
});

/// Vendedores y mercados que existen en las visitas del día, para el filtro.
final vendedoresVisitasProvider = Provider.autoDispose<List<String>>((ref) {
  final todas = ref.watch(visitasProvider).valueOrNull ?? const <Visita>[];
  final valores =
      todas
          .map((v) => v.vendedor)
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return valores;
});

final mercadosVisitasProvider = Provider.autoDispose<List<String>>((ref) {
  final todas = ref.watch(visitasProvider).valueOrNull ?? const <Visita>[];
  final valores =
      todas
          .map((v) => v.mercado)
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return valores;
});

// --- Devoluciones ---

final busquedaDevolucionesProvider = StateProvider.autoDispose((ref) => '');

/// Por estado. Por defecto las que esperan respuesta: es lo único sobre lo
/// que hay algo que hacer.
enum FiltroEstadoDevolucion { solicitadas, aprobadas, rechazadas, todas }

final filtroDevolucionEstadoProvider = StateProvider.autoDispose(
  (ref) => FiltroEstadoDevolucion.solicitadas,
);

final clienteDevolucionFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final motivoDevolucionFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosDevolucionesActivosProvider = Provider.autoDispose((ref) {
  var n =
      ref.watch(filtroDevolucionEstadoProvider) == FiltroEstadoDevolucion.solicitadas
      ? 0
      : 1;
  if (ref.watch(clienteDevolucionFiltroProvider) != null) n++;
  if (ref.watch(motivoDevolucionFiltroProvider) != null) n++;
  return n;
});

final devolucionesProvider = FutureProvider<List<Devolucion>>(
  (ref) => ref.watch(dmsApiProvider).devoluciones(),
);

final resumenDevolucionesProvider = FutureProvider<ResumenDevoluciones>((ref) {
  // Atado al listado: al aprobar o rechazar, los totales se rehacen solos.
  ref.watch(devolucionesProvider);
  return ref.watch(dmsApiProvider).resumenDevoluciones();
});

final devolucionesFiltradasProvider = Provider.autoDispose<List<Devolucion>>((
  ref,
) {
  final todas =
      ref.watch(devolucionesProvider).valueOrNull ?? const <Devolucion>[];
  final texto = ref.watch(busquedaDevolucionesProvider).trim().toLowerCase();
  final filtro = ref.watch(filtroDevolucionEstadoProvider);
  final cliente = ref.watch(clienteDevolucionFiltroProvider);
  final motivo = ref.watch(motivoDevolucionFiltroProvider);

  return todas
      .where(
        (d) => switch (filtro) {
          FiltroEstadoDevolucion.todas => true,
          FiltroEstadoDevolucion.solicitadas =>
            d.estado == EstadoDevolucion.solicitada,
          FiltroEstadoDevolucion.aprobadas => d.estado == EstadoDevolucion.aprobada,
          FiltroEstadoDevolucion.rechazadas => d.estado == EstadoDevolucion.rechazada,
        },
      )
      .where((d) => cliente == null || d.cliente == cliente)
      .where((d) => motivo == null || d.motivo == motivo)
      .where((d) => texto.isEmpty || d.buscable.contains(texto))
      .toList();
});

/// Clientes y motivos que existen en las devoluciones, para el filtro.
final clientesDevolucionProvider = Provider.autoDispose<List<String>>((ref) {
  final todas =
      ref.watch(devolucionesProvider).valueOrNull ?? const <Devolucion>[];
  final valores = todas.map((d) => d.cliente).toSet().toList()..sort();
  return valores;
});

final motivosDevolucionProvider = Provider.autoDispose<List<String>>((ref) {
  final todas =
      ref.watch(devolucionesProvider).valueOrNull ?? const <Devolucion>[];
  final valores =
      todas
          .map((d) => d.motivo)
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return valores;
});
