import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/compra.dart';
import '../datos/compras_api.dart';
import '../datos/orden_compra.dart';

final comprasApiProvider = Provider(
  (ref) => ComprasApi(ref.watch(clienteApiProvider)),
);

// --- Ordenes de compra ---

final busquedaOrdenesCompraProvider = StateProvider.autoDispose((ref) => '');

/// Filtro por estado. Null es "todas".
final estadoOrdenCompraFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

class OrdenesCompraControlador extends AsyncNotifier<List<OrdenCompra>> {
  @override
  Future<List<OrdenCompra>> build() =>
      ref.watch(comprasApiProvider).ordenesCompra();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(comprasApiProvider).ordenesCompra(),
    );
  }

  Future<void> crear(Map<String, dynamic> cuerpo) async {
    await ref.read(comprasApiProvider).crearOrdenCompra(cuerpo);
    await recargar();
  }

  Future<void> actualizar(int id, Map<String, dynamic> cuerpo) async {
    await ref.read(comprasApiProvider).actualizarOrdenCompra(id, cuerpo);
    await recargar();
  }

  Future<void> confirmar(int id) async {
    await ref.read(comprasApiProvider).confirmarOrdenCompra(id);
    await recargar();
    // La confirmacion crea una Compra: si la pantalla de Mis compras esta
    // viva, que la vea sin tener que salir y volver a entrar.
    ref.invalidate(comprasProvider);
  }

  Future<void> anular(int id) async {
    await ref.read(comprasApiProvider).anularOrdenCompra(id);
    await recargar();
  }
}

final ordenesCompraProvider =
    AsyncNotifierProvider<OrdenesCompraControlador, List<OrdenCompra>>(
      OrdenesCompraControlador.new,
    );

final ordenesCompraFiltradasProvider = Provider.autoDispose<List<OrdenCompra>>((
  ref,
) {
  final todas =
      ref.watch(ordenesCompraProvider).valueOrNull ?? const <OrdenCompra>[];
  final texto = ref.watch(busquedaOrdenesCompraProvider).trim().toLowerCase();
  final estado = ref.watch(estadoOrdenCompraFiltroProvider);
  return todas
      .where((o) => estado == null || o.estado == estado)
      .where((o) => texto.isEmpty || o.buscable.contains(texto))
      .toList();
});

// --- Compras ---

final busquedaComprasProvider = StateProvider.autoDispose((ref) => '');

/// Filtro por estado. Null es "todas".
final estadoCompraFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

class ComprasControlador extends AsyncNotifier<List<Compra>> {
  @override
  Future<List<Compra>> build() => ref.watch(comprasApiProvider).compras();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(comprasApiProvider).compras());
  }

  Future<void> crear(Map<String, dynamic> cuerpo) async {
    await ref.read(comprasApiProvider).crearCompra(cuerpo);
    await recargar();
  }

  Future<void> actualizar(int id, Map<String, dynamic> cuerpo) async {
    await ref.read(comprasApiProvider).actualizarCompra(id, cuerpo);
    await recargar();
  }

  Future<void> anular(int id) async {
    await ref.read(comprasApiProvider).anularCompra(id);
    await recargar();
  }
}

final comprasProvider = AsyncNotifierProvider<ComprasControlador, List<Compra>>(
  ComprasControlador.new,
);

final comprasFiltradasProvider = Provider.autoDispose<List<Compra>>((ref) {
  final todas = ref.watch(comprasProvider).valueOrNull ?? const <Compra>[];
  final texto = ref.watch(busquedaComprasProvider).trim().toLowerCase();
  final estado = ref.watch(estadoCompraFiltroProvider);
  return todas
      .where((c) => estado == null || c.estado == estado)
      .where((c) => texto.isEmpty || c.buscable.contains(texto))
      .toList();
});

/// Compras con algo pendiente de recibir, para el selector de Recepciones.
final comprasConPendienteProvider = Provider.autoDispose<List<Compra>>((ref) {
  final todas = ref.watch(comprasProvider).valueOrNull ?? const <Compra>[];
  return todas
      .where(
        (c) =>
            c.estado != EstadoCompra.anulada &&
            c.detalle.any((d) => d.cantidadPendiente > 0),
      )
      .toList();
});

// --- Cuentas por pagar ---

final busquedaCuentasPorPagarProvider = StateProvider.autoDispose<String>((ref) => '');

class CuentasPorPagarControlador extends AsyncNotifier<List<Compra>> {
  @override
  Future<List<Compra>> build() => ref.watch(comprasApiProvider).cuentasPorPagar();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(comprasApiProvider).cuentasPorPagar(),
    );
  }

  Future<void> registrarPago(int compraId, Map<String, dynamic> cuerpo) async {
    await ref.read(comprasApiProvider).registrarPagoCompra(compraId, cuerpo);
    await recargar();
  }

  Future<void> actualizarPago(
    int compraId,
    int pagoId,
    Map<String, dynamic> cuerpo,
  ) async {
    await ref.read(comprasApiProvider).actualizarPagoCompra(compraId, pagoId, cuerpo);
    await recargar();
  }

  Future<void> anularPago(int compraId, int pagoId) async {
    await ref.read(comprasApiProvider).anularPagoCompra(compraId, pagoId);
    await recargar();
  }
}

final cuentasPorPagarProvider =
    AsyncNotifierProvider<CuentasPorPagarControlador, List<Compra>>(
      CuentasPorPagarControlador.new,
    );

final cuentasPorPagarFiltradasProvider = Provider.autoDispose<List<Compra>>((ref) {
  final todas = ref.watch(cuentasPorPagarProvider).valueOrNull ?? const <Compra>[];
  final texto = ref.watch(busquedaCuentasPorPagarProvider).trim().toLowerCase();
  return todas.where((c) => texto.isEmpty || c.buscable.contains(texto)).toList();
});
