import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/estado/filtro_documento.dart';
import '../../auth/estado/auth_controlador.dart';
import '../datos/cobro.dart';
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

/// Contado o credito. Null es "todas": es lo que separa la venta ya cobrada
/// de la que queda por cobrar, y por eso se filtra aparte del estado.
final formaPagoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosNotasVentaActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(filtroDocumentoProvider) != FiltroDocumento.todos) n++;
  if (ref.watch(formaPagoFiltroProvider) != null) n++;
  return n;
});

final notasVentaFiltradasProvider = Provider.autoDispose<List<NotaVenta>>((ref) {
  final todas = ref.watch(notasVentaProvider).valueOrNull ?? const <NotaVenta>[];
  final texto = ref.watch(busquedaNotasVentaProvider).trim().toLowerCase();
  final filtro = ref.watch(filtroDocumentoProvider);
  final forma = ref.watch(formaPagoFiltroProvider);

  return todas
      .where((n) => pasaDocumento(n.estado == EstadoNotaVenta.anulada, filtro))
      .where((n) => forma == null || n.formaPago == forma)
      .where((n) => texto.isEmpty || n.buscable.contains(texto))
      .toList();
});

// --- Cuentas por cobrar ---

final busquedaCuentasPorCobrarProvider = StateProvider.autoDispose<String>((ref) => '');

class CuentasPorCobrarControlador extends AsyncNotifier<List<NotaVenta>> {
  @override
  Future<List<NotaVenta>> build() => ref.watch(ventasApiProvider).cuentasPorCobrar();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(ventasApiProvider).cuentasPorCobrar(),
    );
  }

  Future<void> registrarPago(int notaVentaId, Map<String, dynamic> cuerpo) async {
    await ref.read(ventasApiProvider).registrarPagoNotaVenta(notaVentaId, cuerpo);
    await recargar();
  }

  Future<void> actualizarPago(
    int notaVentaId,
    int pagoId,
    Map<String, dynamic> cuerpo,
  ) async {
    await ref.read(ventasApiProvider).actualizarPagoNotaVenta(notaVentaId, pagoId, cuerpo);
    await recargar();
  }

  Future<void> anularPago(int notaVentaId, int pagoId) async {
    await ref.read(ventasApiProvider).anularPagoNotaVenta(notaVentaId, pagoId);
    await recargar();
  }
}

final cuentasPorCobrarProvider =
    AsyncNotifierProvider<CuentasPorCobrarControlador, List<NotaVenta>>(
      CuentasPorCobrarControlador.new,
    );

/// Cuanto queda de una deuda. Lo que ya se cobro entero sigue en la lista
/// —es el historial—, pero estorba cuando lo que se quiere es salir a cobrar.
enum FiltroDeuda { todas, conSaldo, pagadas }

final filtroDeudaProvider = StateProvider.autoDispose((ref) => FiltroDeuda.todas);

final filtrosDeudaActivosProvider = Provider.autoDispose(
  (ref) => ref.watch(filtroDeudaProvider) == FiltroDeuda.todas ? 0 : 1,
);

bool pasaDeuda(double total, double pagado, FiltroDeuda filtro) =>
    switch (filtro) {
      FiltroDeuda.todas => true,
      // Un centimo de tolerancia: los redondeos no deben dejar una deuda
      // fantasma de S/ 0.001 en la lista de lo que hay que cobrar.
      FiltroDeuda.conSaldo => total - pagado > 0.01,
      FiltroDeuda.pagadas => total - pagado <= 0.01,
    };

final cuentasPorCobrarFiltradasProvider = Provider.autoDispose<List<NotaVenta>>((ref) {
  final todas = ref.watch(cuentasPorCobrarProvider).valueOrNull ?? const <NotaVenta>[];
  final texto = ref.watch(busquedaCuentasPorCobrarProvider).trim().toLowerCase();
  final filtro = ref.watch(filtroDeudaProvider);

  return todas
      .where((n) => pasaDeuda(n.total, n.totalPagado, filtro))
      .where((n) => texto.isEmpty || n.buscable.contains(texto))
      .toList();
});

// --- Mis cobros ---

final busquedaMisCobrosProvider = StateProvider.autoDispose<String>((ref) => '');

class MisCobrosControlador extends AsyncNotifier<List<Cobro>> {
  @override
  Future<List<Cobro>> build() => ref.watch(ventasApiProvider).misCobros();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(ventasApiProvider).misCobros());
  }
}

final misCobrosProvider = AsyncNotifierProvider<MisCobrosControlador, List<Cobro>>(
  MisCobrosControlador.new,
);

final filtrosMisCobrosActivosProvider = Provider.autoDispose(
  (ref) => ref.watch(filtroDocumentoProvider) == FiltroDocumento.todos ? 0 : 1,
);

final misCobrosFiltradosProvider = Provider.autoDispose<List<Cobro>>((ref) {
  final todos = ref.watch(misCobrosProvider).valueOrNull ?? const <Cobro>[];
  final texto = ref.watch(busquedaMisCobrosProvider).trim().toLowerCase();
  final filtro = ref.watch(filtroDocumentoProvider);

  return todos
      .where((c) => pasaDocumento(c.anulado, filtro))
      .where((c) => texto.isEmpty || c.buscable.contains(texto))
      .toList();
});
