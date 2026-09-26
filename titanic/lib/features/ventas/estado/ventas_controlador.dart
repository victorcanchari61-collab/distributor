import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/estado/filtro_documento.dart';
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
final estadoPedidoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final clientePedidoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// null = todos, true = convertido a venta, false = sin convertir.
final ventaPedidoFiltroProvider = StateProvider.autoDispose<bool?>(
  (ref) => null,
);

/// La ruta del cliente. Null es "todas".
final rutaPedidoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// El día de visita del cliente. Null es "todos".
final diaVisitaPedidoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosPedidosActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(estadoPedidoFiltroProvider) != null) n++;
  if (ref.watch(clientePedidoFiltroProvider) != null) n++;
  if (ref.watch(ventaPedidoFiltroProvider) != null) n++;
  if (ref.watch(rutaPedidoFiltroProvider) != null) n++;
  if (ref.watch(diaVisitaPedidoFiltroProvider) != null) n++;
  return n;
});

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

  Future<void> marcarNoEntregado(int id, Map<String, dynamic> cuerpo) async {
    await ref.read(ventasApiProvider).marcarNoEntregado(id, cuerpo);
    await recargar();
  }

  Future<void> quitarNoEntregado(int id) async {
    await ref.read(ventasApiProvider).quitarNoEntregado(id);
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
  final cliente = ref.watch(clientePedidoFiltroProvider);
  final venta = ref.watch(ventaPedidoFiltroProvider);
  final ruta = ref.watch(rutaPedidoFiltroProvider);
  final diaVisita = ref.watch(diaVisitaPedidoFiltroProvider);
  return todos
      .where((p) => estado == null || p.estado == estado)
      .where((p) => cliente == null || p.cliente == cliente)
      .where((p) => venta == null || venta == (p.notaVentaNumero != null))
      .where((p) => ruta == null || p.ruta == ruta)
      .where((p) => diaVisita == null || p.diaVisita == diaVisita)
      .where((p) => texto.isEmpty || p.buscable.contains(texto))
      .toList();
});

/// Clientes que existen en los pedidos, para armar el filtro.
final clientesPedidoProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(pedidosProvider).valueOrNull ?? const <Pedido>[];
  final valores = todos.map((p) => p.cliente).toSet().toList()..sort();
  return valores;
});

/// Rutas que existen en los pedidos, para armar el filtro.
final rutasPedidoProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(pedidosProvider).valueOrNull ?? const <Pedido>[];
  final valores = todos.map((p) => p.ruta).whereType<String>().toSet().toList()
    ..sort((a, b) => a.compareTo(b));
  return valores;
});

/// Los días de visita, en orden de semana, que las rutas de este listado usan.
const diasVisitaOrden = [
  'LUNES',
  'MARTES',
  'MIERCOLES',
  'JUEVES',
  'VIERNES',
  'SABADO',
  'DOMINGO',
];

// --- Notas de venta ---

final busquedaNotasVentaProvider = StateProvider.autoDispose((ref) => '');

class NotasVentaControlador extends AsyncNotifier<List<NotaVenta>> {
  @override
  Future<List<NotaVenta>> build() => ref.watch(ventasApiProvider).notasVenta();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(ventasApiProvider).notasVenta(),
    );
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

final clienteNotaVentaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// null = todas, true = de un pedido, false = directa.
final deUnPedidoFiltroProvider = StateProvider.autoDispose<bool?>(
  (ref) => null,
);

final filtrosNotasVentaActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(filtroDocumentoProvider) != FiltroDocumento.todos) n++;
  if (ref.watch(formaPagoFiltroProvider) != null) n++;
  if (ref.watch(clienteNotaVentaFiltroProvider) != null) n++;
  if (ref.watch(deUnPedidoFiltroProvider) != null) n++;
  return n;
});

final notasVentaFiltradasProvider = Provider.autoDispose<List<NotaVenta>>((
  ref,
) {
  final todas =
      ref.watch(notasVentaProvider).valueOrNull ?? const <NotaVenta>[];
  final texto = ref.watch(busquedaNotasVentaProvider).trim().toLowerCase();
  final filtro = ref.watch(filtroDocumentoProvider);
  final forma = ref.watch(formaPagoFiltroProvider);
  final cliente = ref.watch(clienteNotaVentaFiltroProvider);
  final deUnPedido = ref.watch(deUnPedidoFiltroProvider);

  return todas
      .where((n) => pasaDocumento(n.estado == EstadoNotaVenta.anulada, filtro))
      .where((n) => forma == null || n.formaPago == forma)
      .where((n) => cliente == null || n.cliente == cliente)
      .where((n) => deUnPedido == null || deUnPedido == (n.pedidoId != null))
      .where((n) => texto.isEmpty || n.buscable.contains(texto))
      .toList();
});

/// Clientes que existen en las notas de venta, para armar el filtro.
final clientesNotaVentaProvider = Provider.autoDispose<List<String>>((ref) {
  final todas =
      ref.watch(notasVentaProvider).valueOrNull ?? const <NotaVenta>[];
  final valores = todas.map((n) => n.cliente).toSet().toList()..sort();
  return valores;
});

// --- Cuentas por cobrar ---

final busquedaCuentasPorCobrarProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

class CuentasPorCobrarControlador extends AsyncNotifier<List<NotaVenta>> {
  @override
  Future<List<NotaVenta>> build() =>
      ref.watch(ventasApiProvider).cuentasPorCobrar();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(ventasApiProvider).cuentasPorCobrar(),
    );
  }

  Future<void> registrarPago(
    int notaVentaId,
    Map<String, dynamic> cuerpo,
  ) async {
    await ref
        .read(ventasApiProvider)
        .registrarPagoNotaVenta(notaVentaId, cuerpo);
    await recargar();
  }

  Future<void> actualizarPago(
    int notaVentaId,
    int pagoId,
    Map<String, dynamic> cuerpo,
  ) async {
    await ref
        .read(ventasApiProvider)
        .actualizarPagoNotaVenta(notaVentaId, pagoId, cuerpo);
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

final filtroDeudaProvider = StateProvider.autoDispose(
  (ref) => FiltroDeuda.todas,
);

final filtrosDeudaActivosProvider = Provider.autoDispose(
  (ref) => ref.watch(filtroDeudaProvider) == FiltroDeuda.todas ? 0 : 1,
);

final clienteCuentasPorCobrarFiltroProvider =
    StateProvider.autoDispose<String?>((ref) => null);

bool pasaDeuda(double total, double pagado, FiltroDeuda filtro) =>
    switch (filtro) {
      FiltroDeuda.todas => true,
      // Un centimo de tolerancia: los redondeos no deben dejar una deuda
      // fantasma de S/ 0.001 en la lista de lo que hay que cobrar.
      FiltroDeuda.conSaldo => total - pagado > 0.01,
      FiltroDeuda.pagadas => total - pagado <= 0.01,
    };

final cuentasPorCobrarFiltradasProvider = Provider.autoDispose<List<NotaVenta>>(
  (ref) {
    final todas =
        ref.watch(cuentasPorCobrarProvider).valueOrNull ?? const <NotaVenta>[];
    final texto = ref
        .watch(busquedaCuentasPorCobrarProvider)
        .trim()
        .toLowerCase();
    final filtro = ref.watch(filtroDeudaProvider);
    final cliente = ref.watch(clienteCuentasPorCobrarFiltroProvider);

    return todas
        .where((n) => pasaDeuda(n.total, n.totalPagado, filtro))
        .where((n) => cliente == null || n.cliente == cliente)
        .where((n) => texto.isEmpty || n.buscable.contains(texto))
        .toList();
  },
);

/// Clientes que existen en las cuentas por cobrar.
final clientesCuentasPorCobrarProvider = Provider.autoDispose<List<String>>((
  ref,
) {
  final todas =
      ref.watch(cuentasPorCobrarProvider).valueOrNull ?? const <NotaVenta>[];
  final valores = todas.map((n) => n.cliente).toSet().toList()..sort();
  return valores;
});

// --- Recojos ---

/// Los recojos que todavía no entraron a ningún almacén: el repartidor no
/// elige el almacén, así que quedan aquí hasta que se revisan en Novedades
/// de entrega.
class RecojosPendientesControlador
    extends AsyncNotifier<List<RecojoPendiente>> {
  @override
  Future<List<RecojoPendiente>> build() =>
      ref.watch(ventasApiProvider).recojosPendientes();

  Future<void> recargar() async {
    state = await AsyncValue.guard(
      () => ref.read(ventasApiProvider).recojosPendientes(),
    );
  }

  /// El encargado dice a qué almacén entra: recién ahí suma stock.
  Future<void> verificar(int id, Map<String, dynamic> cuerpo) async {
    await ref.read(ventasApiProvider).verificarRecojo(id, cuerpo);
    await recargar();
  }
}

final recojosPendientesProvider =
    AsyncNotifierProvider<RecojosPendientesControlador, List<RecojoPendiente>>(
      RecojosPendientesControlador.new,
    );
