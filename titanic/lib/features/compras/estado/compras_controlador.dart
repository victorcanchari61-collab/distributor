import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ventas/estado/ventas_controlador.dart';
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
final proveedorOrdenCompraFiltroProvider = StateProvider.autoDispose<String?>(
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
  final proveedor = ref.watch(proveedorOrdenCompraFiltroProvider);
  return todas
      .where((o) => estado == null || o.estado == estado)
      .where((o) => proveedor == null || o.proveedor == proveedor)
      .where((o) => texto.isEmpty || o.buscable.contains(texto))
      .toList();
});

/// Proveedores que existen en las ordenes, para armar el filtro.
final proveedoresOrdenCompraProvider = Provider.autoDispose<List<String>>((
  ref,
) {
  final todas =
      ref.watch(ordenesCompraProvider).valueOrNull ?? const <OrdenCompra>[];
  final valores = todas.map((o) => o.proveedor).toSet().toList()..sort();
  return valores;
});

// --- Compras ---

final busquedaComprasProvider = StateProvider.autoDispose((ref) => '');

/// Filtro por estado. Null es "todas".
final estadoCompraFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final proveedorCompraFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final tipoComprobanteFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// null = todas, true = de una orden, false = directa.
final deOrdenFiltroProvider = StateProvider.autoDispose<bool?>((ref) => null);

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
  final proveedor = ref.watch(proveedorCompraFiltroProvider);
  final tipoComprobante = ref.watch(tipoComprobanteFiltroProvider);
  final deOrden = ref.watch(deOrdenFiltroProvider);
  return todas
      .where((c) => estado == null || c.estado == estado)
      .where((c) => proveedor == null || c.proveedor == proveedor)
      .where(
        (c) => tipoComprobante == null || c.tipoComprobante == tipoComprobante,
      )
      .where((c) => deOrden == null || deOrden == (c.ordenCompraId != null))
      .where((c) => texto.isEmpty || c.buscable.contains(texto))
      .toList();
});

/// Proveedores que existen en las compras, para armar el filtro.
final proveedoresCompraProvider = Provider.autoDispose<List<String>>((ref) {
  final todas = ref.watch(comprasProvider).valueOrNull ?? const <Compra>[];
  final valores = todas.map((c) => c.proveedor).toSet().toList()..sort();
  return valores;
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
final proveedorCuentasPorPagarFiltroProvider =
    StateProvider.autoDispose<String?>((ref) => null);

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
  final filtro = ref.watch(filtroDeudaProvider);
  final proveedor = ref.watch(proveedorCuentasPorPagarFiltroProvider);

  return todas
      .where((c) => pasaDeuda(c.total, c.totalPagado, filtro))
      .where((c) => proveedor == null || c.proveedor == proveedor)
      .where((c) => texto.isEmpty || c.buscable.contains(texto))
      .toList();
});

/// Proveedores que existen en las cuentas por pagar.
final proveedoresCuentasPorPagarProvider = Provider.autoDispose<List<String>>((
  ref,
) {
  final todas = ref.watch(cuentasPorPagarProvider).valueOrNull ?? const <Compra>[];
  final valores = todas.map((c) => c.proveedor).toSet().toList()..sort();
  return valores;
});
