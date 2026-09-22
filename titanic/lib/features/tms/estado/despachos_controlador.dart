import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/despacho.dart';
import '../datos/despacho_api.dart';

final despachoApiProvider = Provider(
  (ref) => DespachoApi(ref.watch(clienteApiProvider)),
);

final busquedaDespachosProvider = StateProvider.autoDispose((ref) => '');

/// Filtros propios de despachos. Null es "todos".
final estadoDespachoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final rutaDespachoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final vehiculoDespachoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final conductorDespachoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosDespachosActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(estadoDespachoFiltroProvider) != null) n++;
  if (ref.watch(rutaDespachoFiltroProvider) != null) n++;
  if (ref.watch(vehiculoDespachoFiltroProvider) != null) n++;
  if (ref.watch(conductorDespachoFiltroProvider) != null) n++;
  return n;
});

/// Listado de despachos.
class DespachosControlador extends AsyncNotifier<List<Despacho>> {
  @override
  Future<List<Despacho>> build() => ref.watch(despachoApiProvider).despachos();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(despachoApiProvider).despachos(),
    );
  }

  Future<void> crear(Map<String, dynamic> cuerpo) async {
    await ref.read(despachoApiProvider).crear(cuerpo);
    await recargar();
  }

  Future<void> actualizar(int id, Map<String, dynamic> cuerpo) async {
    await ref.read(despachoApiProvider).actualizar(id, cuerpo);
    await recargar();
  }

  Future<void> anular(int id) async {
    await ref.read(despachoApiProvider).anular(id);
    await recargar();
  }
}

final despachosProvider =
    AsyncNotifierProvider<DespachosControlador, List<Despacho>>(
      DespachosControlador.new,
    );

final resumenDespachosProvider = FutureProvider.autoDispose<ResumenDespachos>((
  ref,
) {
  // Atado al listado: al armar o anular un despacho, los totales se rehacen solos.
  ref.watch(despachosProvider);
  return ref.watch(despachoApiProvider).resumen();
});

final despachosFiltradosProvider = Provider.autoDispose<List<Despacho>>((ref) {
  final todos = ref.watch(despachosProvider).valueOrNull ?? const <Despacho>[];
  final texto = ref.watch(busquedaDespachosProvider).trim().toLowerCase();
  final estado = ref.watch(estadoDespachoFiltroProvider);
  final ruta = ref.watch(rutaDespachoFiltroProvider);
  final vehiculo = ref.watch(vehiculoDespachoFiltroProvider);
  final conductor = ref.watch(conductorDespachoFiltroProvider);

  return todos
      .where((d) => estado == null || d.estado == estado)
      .where((d) => ruta == null || d.ruta == ruta)
      .where((d) => vehiculo == null || d.vehiculo == vehiculo)
      .where((d) => conductor == null || d.conductor == conductor)
      .where((d) => texto.isEmpty || d.buscable.contains(texto))
      .toList();
});

/// Los pedidos pendientes de una ruta, para armar o editar un despacho.
///
/// `despachoId` viaja en la clave: al editar, el backend suma los propios
/// pedidos del despacho aunque ya no estén "disponibles" para otro camión.
///
/// Las rutas viajan como texto ("1,7") y no como lista: la clave de un `family` se compara por igualdad, y
/// dos listas iguales no lo son — cada rebuild pediría los pedidos otra vez, sin parar.
typedef ClaveDisponibles = ({String rutas, int? despachoId, String? dia});

final disponiblesProvider = FutureProvider.autoDispose
    .family<List<DespachoPedido>, ClaveDisponibles>(
      (ref, clave) => ref
          .watch(despachoApiProvider)
          .disponibles(
            [
              for (final r in clave.rutas.split(','))
                if (r.isNotEmpty) int.parse(r),
            ],
            despachoId: clave.despachoId,
            diaVisita: clave.dia,
          ),
    );

/// El recorrido semanal de un vehículo, para proponer las rutas de un despacho.
final recorridoVehiculoProvider = FutureProvider.autoDispose
    .family<Map<String, List<int>>, int>(
      (ref, vehiculoId) =>
          ref.watch(despachoApiProvider).recorridoDe(vehiculoId),
    );

/// Lo que ese camión lleva, para recortar el reporte de carga.
final opcionesCargaProvider = FutureProvider.autoDispose
    .family<OpcionesCarga, int>(
      (ref, despachoId) =>
          ref.watch(despachoApiProvider).opcionesCarga(despachoId),
    );
