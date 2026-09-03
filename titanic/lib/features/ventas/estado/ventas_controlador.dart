import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/nota_venta.dart';
import '../datos/pedido.dart';
import '../datos/ventas_api.dart';

final ventasApiProvider = Provider(
  (ref) => VentasApi(ref.watch(clienteApiProvider)),
);

// --- Pedidos ---

final busquedaPedidosProvider = StateProvider.autoDispose((ref) => '');

/// Filtro por estado. Null es "todos".
final estadoPedidoFiltroProvider = StateProvider.autoDispose<String?>((ref) => null);

class PedidosControlador extends AsyncNotifier<List<Pedido>> {
  @override
  Future<List<Pedido>> build() => ref.watch(ventasApiProvider).pedidos();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(ventasApiProvider).pedidos());
  }

  Future<void> crear(Map<String, dynamic> cuerpo) async {
    await ref.read(ventasApiProvider).crearPedido(cuerpo);
    await recargar();
  }

  Future<void> actualizar(int id, Map<String, dynamic> cuerpo) async {
    await ref.read(ventasApiProvider).actualizarPedido(id, cuerpo);
    await recargar();
  }

  Future<void> confirmar(int id, Map<String, dynamic> cuerpo) async {
    await ref.read(ventasApiProvider).confirmarPedido(id, cuerpo);
    await recargar();
    // La confirmacion crea una NotaVenta: si esa pantalla esta viva, que la
    // vea sin tener que salir y volver a entrar.
    ref.invalidate(notasVentaProvider);
  }

  Future<void> anular(int id) async {
    await ref.read(ventasApiProvider).anularPedido(id);
    await recargar();
  }
}

final pedidosProvider = AsyncNotifierProvider<PedidosControlador, List<Pedido>>(
  PedidosControlador.new,
);

final pedidosFiltradosProvider = Provider.autoDispose<List<Pedido>>((ref) {
  final todos = ref.watch(pedidosProvider).valueOrNull ?? const <Pedido>[];
  final texto = ref.watch(busquedaPedidosProvider).trim().toLowerCase();
  final estado = ref.watch(estadoPedidoFiltroProvider);
  return todos
      .where((p) => estado == null || p.estado == estado)
      .where((p) => texto.isEmpty || p.buscable.contains(texto))
      .toList();
});

// --- Notas de venta ---

final busquedaNotasVentaProvider = StateProvider.autoDispose((ref) => '');

class NotasVentaControlador extends AsyncNotifier<List<NotaVenta>> {
  @override
  Future<List<NotaVenta>> build() => ref.watch(ventasApiProvider).notasVenta();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(ventasApiProvider).notasVenta());
  }

  Future<void> crear(Map<String, dynamic> cuerpo) async {
    await ref.read(ventasApiProvider).crearNotaVenta(cuerpo);
    await recargar();
  }

  Future<void> anular(int id) async {
    await ref.read(ventasApiProvider).anularNotaVenta(id);
    await recargar();
  }
}

final notasVentaProvider =
    AsyncNotifierProvider<NotasVentaControlador, List<NotaVenta>>(
      NotasVentaControlador.new,
    );

final notasVentaFiltradasProvider = Provider.autoDispose<List<NotaVenta>>((ref) {
  final todas = ref.watch(notasVentaProvider).valueOrNull ?? const <NotaVenta>[];
  final texto = ref.watch(busquedaNotasVentaProvider).trim().toLowerCase();
  return todas.where((n) => texto.isEmpty || n.buscable.contains(texto)).toList();
});
