import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/mercado.dart';
import '../datos/tms_api.dart';

final tmsApiProvider = Provider((ref) => TmsApi(ref.watch(clienteApiProvider)));

final busquedaMercadosProvider = StateProvider.autoDispose((ref) => '');

/// Listado de mercados.
class MercadosControlador extends AsyncNotifier<List<Mercado>> {
  @override
  Future<List<Mercado>> build() => ref.watch(tmsApiProvider).mercados();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(tmsApiProvider).mercados());
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(tmsApiProvider);
    if (id == null) {
      await api.crearMercado(cuerpo);
    } else {
      await api.actualizarMercado(id, cuerpo);
    }
    await recargar();
  }

  Future<void> cambiarEstado(Mercado mercado) async {
    await ref.read(tmsApiProvider).actualizarMercado(mercado.id, {
      'nombre': mercado.nombre,
      'direccion': mercado.direccion,
      'distrito': mercado.distrito,
      'activo': !mercado.activo,
    });
    await recargar();
  }

  Future<void> eliminar(int id) async {
    await ref.read(tmsApiProvider).eliminarMercado(id);
    await recargar();
  }
}

final mercadosProvider = AsyncNotifierProvider<MercadosControlador, List<Mercado>>(
  MercadosControlador.new,
);

final mercadosFiltradosProvider = Provider.autoDispose<List<Mercado>>((ref) {
  final todos = ref.watch(mercadosProvider).valueOrNull ?? const <Mercado>[];
  final texto = ref.watch(busquedaMercadosProvider).trim().toLowerCase();
  return todos.where((m) => texto.isEmpty || m.buscable.contains(texto)).toList();
});

/// Mercados activos, para el selector del formulario de Clientes.
final mercadosActivosProvider = Provider.autoDispose<List<Mercado>>(
  (ref) => (ref.watch(mercadosProvider).valueOrNull ?? const <Mercado>[])
      .where((m) => m.activo)
      .toList(),
);
