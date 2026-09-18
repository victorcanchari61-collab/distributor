import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/facturacion_api.dart';
import '../datos/lista_precio.dart';

final facturacionApiProvider = Provider(
  (ref) => FacturacionApi(ref.watch(clienteApiProvider)),
);

class ListasPrecioControlador extends AsyncNotifier<List<ListaPrecio>> {
  @override
  Future<List<ListaPrecio>> build() => ref.watch(facturacionApiProvider).listasPrecio();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(facturacionApiProvider).listasPrecio());
  }

  Future<ListaPrecio> crear(Map<String, dynamic> cuerpo) async {
    final lista = await ref.read(facturacionApiProvider).crearLista(cuerpo);
    await recargar();
    return lista;
  }

  Future<void> actualizar(int id, Map<String, dynamic> cuerpo) async {
    await ref.read(facturacionApiProvider).actualizarLista(id, cuerpo);
    await recargar();
  }

  Future<void> marcarPredeterminada(int id) async {
    await ref.read(facturacionApiProvider).marcarPredeterminada(id);
    await recargar();
  }

  Future<void> eliminar(int id) async {
    await ref.read(facturacionApiProvider).eliminarLista(id);
    await recargar();
  }
}

final listasPrecioProvider =
    AsyncNotifierProvider<ListasPrecioControlador, List<ListaPrecio>>(
      ListasPrecioControlador.new,
    );

/// Lista elegida en las pestañas. Null hasta que se cargan las listas.
final listaPrecioActivaProvider = StateProvider.autoDispose<int?>((ref) => null);

final busquedaPreciosProvider = StateProvider.autoDispose((ref) => '');

final preciosListaActivaProvider = FutureProvider.autoDispose<List<Precio>>((ref) {
  final listaId = ref.watch(listaPrecioActivaProvider);
  if (listaId == null) return Future.value(const []);
  return ref.watch(facturacionApiProvider).preciosDeLista(listaId);
});

final presentacionPrecioFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosPreciosActivosProvider = Provider.autoDispose(
  (ref) => ref.watch(presentacionPrecioFiltroProvider) == null ? 0 : 1,
);

final preciosFiltradosProvider = Provider.autoDispose<List<Precio>>((ref) {
  final todos = ref.watch(preciosListaActivaProvider).valueOrNull ?? const <Precio>[];
  final texto = ref.watch(busquedaPreciosProvider).trim().toLowerCase();
  final presentacion = ref.watch(presentacionPrecioFiltroProvider);
  return todos
      .where((p) => presentacion == null || p.presentacion == presentacion)
      .where((p) => texto.isEmpty || p.buscable.contains(texto))
      .toList();
});

/// Presentaciones que existen en la lista activa, para armar el filtro.
final presentacionesDePreciosProvider = Provider.autoDispose<List<String>>((
  ref,
) {
  final todos = ref.watch(preciosListaActivaProvider).valueOrNull ?? const <Precio>[];
  return <String>{for (final p in todos) p.presentacion}.toList()..sort();
});
