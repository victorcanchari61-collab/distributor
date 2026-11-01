import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/comprobante.dart';
import '../datos/comprobantes_api.dart';

final comprobantesApiProvider = Provider(
  (ref) => ComprobantesApi(ref.watch(clienteApiProvider)),
);

/// Los comprobantes de UN tipo (factura, boleta, nota de crédito o de débito): cada uno es una pantalla.
class ComprobantesControlador
    extends FamilyAsyncNotifier<List<Comprobante>, String> {
  @override
  Future<List<Comprobante>> build(String tipo) =>
      ref.watch(comprobantesApiProvider).listar(tipo);

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(comprobantesApiProvider).listar(arg),
    );
  }

  /// Cambia uno de la lista por su versión nueva (después de enviarlo por WhatsApp), sin recargar todo.
  void reemplazar(Comprobante nuevo) {
    final lista = state.valueOrNull;
    if (lista == null) return;
    state = AsyncData([
      for (final c in lista)
        if (c.id == nuevo.id) nuevo else c,
    ]);
  }
}

final comprobantesProvider =
    AsyncNotifierProvider.family<
      ComprobantesControlador,
      List<Comprobante>,
      String
    >(ComprobantesControlador.new);

final busquedaComprobantesProvider = StateProvider.autoDispose
    .family<String, String>((ref, tipo) => '');

final comprobantesFiltradosProvider = Provider.autoDispose
    .family<List<Comprobante>, String>((ref, tipo) {
      final todos =
          ref.watch(comprobantesProvider(tipo)).valueOrNull ??
          const <Comprobante>[];
      final texto = ref
          .watch(busquedaComprobantesProvider(tipo))
          .trim()
          .toLowerCase();
      return todos
          .where((c) => texto.isEmpty || c.buscable.contains(texto))
          .toList();
    });
