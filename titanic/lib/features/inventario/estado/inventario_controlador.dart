import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/estado/filtro_estado.dart';
import '../../auth/estado/auth_controlador.dart';
import '../../compras/estado/compras_controlador.dart';
import '../datos/almacen.dart';
import '../datos/documento_inventario.dart';
import '../datos/inventario_api.dart';
import '../datos/kardex.dart';
import '../datos/lote.dart';
import '../datos/motivo.dart';
import '../datos/prestamo.dart';
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

/// Lo disponible por producto en UN almacen: producto -> disponible.
///
/// Es lo que necesita el buscador de productos al vender: el vendedor tiene
/// que ver lo que de verdad hay donde se va a despachar, no un total de toda
/// la empresa que incluye mercaderia de otro deposito.
///
/// "Disponible" ya descuenta lo que apartaron los pedidos con reserva: es lo
/// que se puede prometer sin comprometer dos veces el mismo saco.
final stockDisponibleProvider = FutureProvider.autoDispose
    .family<Map<int, double>, int?>((ref, almacenId) async {
      final filas = await ref.watch(inventarioApiProvider).stock(almacenId: almacenId);
      return {for (final f in filas) f.productoId: f.disponible};
    });

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

// --- Recepciones ---

final busquedaRecepcionesProvider = StateProvider.autoDispose((ref) => '');

class RecepcionesControlador extends AsyncNotifier<List<DocumentoInventario>> {
  @override
  Future<List<DocumentoInventario>> build() =>
      ref.watch(inventarioApiProvider).recepciones();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(inventarioApiProvider).recepciones(),
    );
  }

  Future<void> crear(Map<String, dynamic> cuerpo) async {
    await ref.read(inventarioApiProvider).crearRecepcion(cuerpo);
    await recargar();
    // La compra que se recibio cambia de estado (parcial/total): que la
    // pantalla de Mis compras lo refleje sin salir y volver a entrar.
    ref.invalidate(comprasProvider);
  }

  Future<void> anular(int id) async {
    await ref.read(inventarioApiProvider).anularRecepcion(id);
    await recargar();
    ref.invalidate(comprasProvider);
  }
}

final recepcionesProvider =
    AsyncNotifierProvider<RecepcionesControlador, List<DocumentoInventario>>(
      RecepcionesControlador.new,
    );

final recepcionesFiltradasProvider = Provider.autoDispose<List<DocumentoInventario>>((
  ref,
) {
  final todas =
      ref.watch(recepcionesProvider).valueOrNull ?? const <DocumentoInventario>[];
  final texto = ref.watch(busquedaRecepcionesProvider).trim().toLowerCase();
  return todas.where((d) => texto.isEmpty || d.buscable.contains(texto)).toList();
});

// --- Motivos ---

final busquedaMotivosProvider = StateProvider.autoDispose((ref) => '');

class MotivosControlador extends AsyncNotifier<List<Motivo>> {
  @override
  Future<List<Motivo>> build() => ref.watch(inventarioApiProvider).motivos();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(inventarioApiProvider).motivos());
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(inventarioApiProvider);
    if (id == null) {
      await api.crearMotivo(cuerpo);
    } else {
      await api.actualizarMotivo(id, cuerpo);
    }
    await recargar();
  }

  Future<void> eliminar(int id) async {
    await ref.read(inventarioApiProvider).eliminarMotivo(id);
    await recargar();
  }
}

final motivosProvider = AsyncNotifierProvider<MotivosControlador, List<Motivo>>(
  MotivosControlador.new,
);

/// Motivos manuales y activos: los unicos que se ofrecen al armar un ajuste.
/// Los del sistema (venta, compra...) no se eligen a mano.
final motivosDisponiblesProvider = Provider.autoDispose<List<Motivo>>((ref) {
  final todos = ref.watch(motivosProvider).valueOrNull ?? const <Motivo>[];
  return todos.where((m) => !m.delSistema && m.activo).toList();
});

final motivosFiltradosProvider = Provider.autoDispose<List<Motivo>>((ref) {
  final todos = ref.watch(motivosProvider).valueOrNull ?? const <Motivo>[];
  final texto = ref.watch(busquedaMotivosProvider).trim().toLowerCase();
  return todos
      .where((m) => !m.delSistema)
      .where((m) => texto.isEmpty || m.buscable.contains(texto))
      .toList();
});

// --- Ajustes ---

final busquedaAjustesProvider = StateProvider.autoDispose((ref) => '');

class AjustesControlador extends AsyncNotifier<List<DocumentoInventario>> {
  @override
  Future<List<DocumentoInventario>> build() => ref.watch(inventarioApiProvider).ajustes();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(inventarioApiProvider).ajustes());
  }

  Future<void> crear(Map<String, dynamic> cuerpo) async {
    await ref.read(inventarioApiProvider).crearAjuste(cuerpo);
    await recargar();
  }

  Future<void> anular(int id) async {
    await ref.read(inventarioApiProvider).anularAjuste(id);
    await recargar();
  }
}

final ajustesProvider =
    AsyncNotifierProvider<AjustesControlador, List<DocumentoInventario>>(
      AjustesControlador.new,
    );

final ajustesFiltradosProvider = Provider.autoDispose<List<DocumentoInventario>>((ref) {
  final todos = ref.watch(ajustesProvider).valueOrNull ?? const <DocumentoInventario>[];
  final texto = ref.watch(busquedaAjustesProvider).trim().toLowerCase();
  return todos.where((d) => texto.isEmpty || d.buscable.contains(texto)).toList();
});

// --- Transferencias ---

final busquedaTransferenciasProvider = StateProvider.autoDispose((ref) => '');

class TransferenciasControlador extends AsyncNotifier<List<DocumentoInventario>> {
  @override
  Future<List<DocumentoInventario>> build() =>
      ref.watch(inventarioApiProvider).transferencias();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(inventarioApiProvider).transferencias());
  }

  Future<void> crear(Map<String, dynamic> cuerpo) async {
    await ref.read(inventarioApiProvider).crearTransferencia(cuerpo);
    await recargar();
  }

  /// Mismo endpoint generico que Ajustes: no hay uno propio de transferencias.
  Future<void> anular(int id) async {
    await ref.read(inventarioApiProvider).anularAjuste(id);
    await recargar();
  }
}

final transferenciasProvider =
    AsyncNotifierProvider<TransferenciasControlador, List<DocumentoInventario>>(
      TransferenciasControlador.new,
    );

final transferenciasFiltradasProvider =
    Provider.autoDispose<List<DocumentoInventario>>((ref) {
      final todos =
          ref.watch(transferenciasProvider).valueOrNull ?? const <DocumentoInventario>[];
      final texto = ref.watch(busquedaTransferenciasProvider).trim().toLowerCase();
      return todos.where((d) => texto.isEmpty || d.buscable.contains(texto)).toList();
    });

// --- Prestamos ---

final busquedaPrestamosProvider = StateProvider.autoDispose((ref) => '');

class PrestamosControlador extends AsyncNotifier<List<Prestamo>> {
  @override
  Future<List<Prestamo>> build() => ref.watch(inventarioApiProvider).prestamos();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(inventarioApiProvider).prestamos());
  }

  Future<void> crear(Map<String, dynamic> cuerpo) async {
    await ref.read(inventarioApiProvider).crearPrestamo(cuerpo);
    await recargar();
  }

  Future<void> devolver(int id, Map<String, dynamic> cuerpo) async {
    await ref.read(inventarioApiProvider).registrarDevolucion(id, cuerpo);
    await recargar();
  }
}

final prestamosProvider =
    AsyncNotifierProvider<PrestamosControlador, List<Prestamo>>(
      PrestamosControlador.new,
    );

final prestamosFiltradosProvider = Provider.autoDispose<List<Prestamo>>((ref) {
  final todos = ref.watch(prestamosProvider).valueOrNull ?? const <Prestamo>[];
  final texto = ref.watch(busquedaPrestamosProvider).trim().toLowerCase();
  return todos.where((p) => texto.isEmpty || p.buscable.contains(texto)).toList();
});

// --- Conteos ciclicos ---
//
// No tiene documento ni endpoint propio: es un ajuste guiado. Su propio
// almacen de contexto, separado del de la pantalla de Stock, para no
// interferir con esa seleccion.

final almacenConteoProvider = StateProvider.autoDispose<int?>((ref) => null);

final stockConteoProvider = FutureProvider.autoDispose<List<Stock>>((ref) {
  final almacenId = ref.watch(almacenConteoProvider);
  if (almacenId == null) return Future.value(const []);
  return ref.watch(inventarioApiProvider).stock(almacenId: almacenId);
});
