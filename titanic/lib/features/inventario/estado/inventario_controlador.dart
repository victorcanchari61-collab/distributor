import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/estado/filtro_estado.dart';
import '../../auth/estado/auth_controlador.dart';
import '../datos/almacen.dart';
import '../datos/inventario_api.dart';
import '../datos/kardex.dart';
import '../datos/lote.dart';
import '../datos/stock.dart';

final inventarioApiProvider = Provider(
  (ref) => InventarioApi(ref.watch(clienteApiProvider)),
);

// --- Almacenes ---

final busquedaAlmacenesProvider = StateProvider.autoDispose((ref) => '');

final filtrosAlmacenesActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(estadoFiltroProvider) != FiltroEstado.activos) n++;
  return n;
});

/// Listado de almacenes.
class AlmacenesControlador extends AsyncNotifier<List<Almacen>> {
  @override
  Future<List<Almacen>> build() => ref.watch(inventarioApiProvider).almacenes();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(inventarioApiProvider).almacenes(),
    );
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(inventarioApiProvider);
    if (id == null) {
      await api.crearAlmacen(cuerpo);
    } else {
      await api.actualizarAlmacen(id, cuerpo);
    }
    await recargar();
  }

  /// El AlmacenController no tiene activar/desactivar propio: se manda el
  /// mismo PUT con el estado invertido, igual que hace el panel web.
  Future<void> cambiarEstado(Almacen almacen) async {
    await ref
        .read(inventarioApiProvider)
        .actualizarAlmacen(almacen.id, {
          'codigo': almacen.codigo,
          'nombre': almacen.nombre,
          'direccion': almacen.direccion,
          'activo': !almacen.activo,
        });
    await recargar();
  }
}

final almacenesProvider =
    AsyncNotifierProvider<AlmacenesControlador, List<Almacen>>(
      AlmacenesControlador.new,
    );

final almacenesFiltradosProvider = Provider.autoDispose<List<Almacen>>((ref) {
  final todos = ref.watch(almacenesProvider).valueOrNull ?? const <Almacen>[];
  final texto = ref.watch(busquedaAlmacenesProvider).trim().toLowerCase();
  final estado = ref.watch(estadoFiltroProvider);

  return todos
      .where((a) => pasaEstado(a.activo, estado))
      .where((a) => texto.isEmpty || a.buscable.contains(texto))
      .toList();
});

/// Almacenes activos, para los selectores de Stock y Kardex: no tiene sentido
/// filtrar por uno que ya no recibe movimientos.
final almacenesActivosProvider = Provider.autoDispose<List<Almacen>>(
  (ref) =>
      (ref.watch(almacenesProvider).valueOrNull ?? const <Almacen>[])
          .where((a) => a.activo)
          .toList(),
);

// --- Stock ---
//
// Es una consulta: aqui no se mueve stock, solo se mira. El almacen es un
// cambio de contexto completo (otro stock, otro valorizado), no un filtro
// mas — por eso vive en su propio provider y no junto al buscador.

/// Almacen elegido en la pantalla de Stock. Null es "Todos".
final almacenStockProvider = StateProvider.autoDispose<int?>((ref) => null);
final busquedaStockProvider = StateProvider.autoDispose((ref) => '');

final stockProvider = FutureProvider.autoDispose<List<Stock>>(
  (ref) => ref
      .watch(inventarioApiProvider)
      .stock(almacenId: ref.watch(almacenStockProvider)),
);

final stockFiltradoProvider = Provider.autoDispose<List<Stock>>((ref) {
  final todos = ref.watch(stockProvider).valueOrNull ?? const <Stock>[];
  final texto = ref.watch(busquedaStockProvider).trim().toLowerCase();
  return todos.where((s) => texto.isEmpty || s.buscable.contains(texto)).toList();
});

// --- Kardex ---

/// Almacen elegido en la pantalla de Kardex. Null es "Todos".
final almacenKardexProvider = StateProvider.autoDispose<int?>((ref) => null);
final busquedaKardexProvider = StateProvider.autoDispose((ref) => '');

final kardexProvider = FutureProvider.autoDispose<List<MovimientoKardex>>(
  (ref) => ref
      .watch(inventarioApiProvider)
      .kardex(almacenId: ref.watch(almacenKardexProvider)),
);

final kardexFiltradoProvider =
    Provider.autoDispose<List<MovimientoKardex>>((ref) {
      final todos =
          ref.watch(kardexProvider).valueOrNull ?? const <MovimientoKardex>[];
      final texto = ref.watch(busquedaKardexProvider).trim().toLowerCase();
      return todos
          .where((k) => texto.isEmpty || k.buscable.contains(texto))
          .toList();
    });

// --- Lotes y vencimientos ---

final busquedaLotesProvider = StateProvider.autoDispose((ref) => '');

final lotesProvider = FutureProvider.autoDispose<List<Lote>>(
  (ref) => ref.watch(inventarioApiProvider).lotes(),
);

final lotesFiltradosProvider = Provider.autoDispose<List<Lote>>((ref) {
  final todos = ref.watch(lotesProvider).valueOrNull ?? const <Lote>[];
  final texto = ref.watch(busquedaLotesProvider).trim().toLowerCase();
  return todos.where((l) => texto.isEmpty || l.buscable.contains(texto)).toList();
});
