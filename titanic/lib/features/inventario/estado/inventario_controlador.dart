import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/estado/filtro_documento.dart';
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
  if (ref.watch(direccionAlmacenFiltroProvider) != null) n++;
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
    // Los selectores de almacén de pedidos y compras leen su propia lista: si
    // se crea o desactiva uno, tiene que aparecer o irse también ahí.
    ref.invalidate(almacenesOpcionesProvider);
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
    await ref.read(inventarioApiProvider).actualizarAlmacen(almacen.id, {
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

final direccionAlmacenFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final almacenesFiltradosProvider = Provider.autoDispose<List<Almacen>>((ref) {
  final todos = ref.watch(almacenesProvider).valueOrNull ?? const <Almacen>[];
  final texto = ref.watch(busquedaAlmacenesProvider).trim().toLowerCase();
  final estado = ref.watch(estadoFiltroProvider);
  final direccion = ref.watch(direccionAlmacenFiltroProvider);

  return todos
      .where((a) => pasaEstado(a.activo, estado))
      .where((a) => direccion == null || a.direccion == direccion)
      .where((a) => texto.isEmpty || a.buscable.contains(texto))
      .toList();
});

/// Direcciones que existen en los almacenes, para armar el filtro.
final direccionesAlmacenProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(almacenesProvider).valueOrNull ?? const <Almacen>[];
  return <String>{
    for (final a in todos)
      if (a.direccion != null && a.direccion!.isNotEmpty) a.direccion!,
  }.toList()..sort();
});

/// Almacenes activos, para los selectores de Stock y Kardex: no tiene sentido
/// filtrar por uno que ya no recibe movimientos.
/// Los almacenes activos, para elegir uno.
///
/// No sale de [almacenesProvider]: ese pide el permiso de la pantalla de
/// Almacenes, y quien toma un pedido o recibe una compra no tiene por qué
/// tenerlo. Colgado de él, un vendedor recibía un 403 y el selector de almacén
/// salía vacío.
final almacenesOpcionesProvider = FutureProvider<List<Almacen>>(
  (ref) => ref.watch(inventarioApiProvider).almacenesOpciones(),
);

final almacenesActivosProvider = Provider.autoDispose<List<Almacen>>(
  (ref) =>
      (ref.watch(almacenesOpcionesProvider).valueOrNull ?? const <Almacen>[])
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
      // Solo el numero, sin costos: lo leen pedidos, ventas y compras.
      return ref.watch(inventarioApiProvider).disponible(almacenId: almacenId);
    });

/// Lo reservado por producto en UN almacen: producto -> reservado.
///
/// Aparte de [stockDisponibleProvider] porque es solo informativo — el
/// buscador de productos lo muestra como aviso ("5 reservados, 10 libres"),
/// pero no impide pedir más de lo disponible.
final stockReservadoProvider = FutureProvider.autoDispose
    .family<Map<int, double>, int?>((ref, almacenId) async {
      return ref.watch(inventarioApiProvider).reservado(almacenId: almacenId);
    });

/// Que se mira del almacen: todo, lo que falta reponer o lo que no se mueve.
enum FiltroStock { todos, bajoMinimo, sinStock, conStock }

final filtroStockProvider = StateProvider.autoDispose(
  (ref) => FiltroStock.todos,
);
final categoriaStockProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final marcaStockProvider = StateProvider.autoDispose<String?>((ref) => null);

final filtrosStockActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(filtroStockProvider) != FiltroStock.todos) n++;
  if (ref.watch(categoriaStockProvider) != null) n++;
  if (ref.watch(marcaStockProvider) != null) n++;
  return n;
});

/// Las categorias que de verdad aparecen en el almacen que se esta mirando.
///
/// No el catalogo entero: ofrecer rubros que no tienen ni un producto aqui
/// llena el filtro de opciones que no devuelven nada.
final categoriasDelStockProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(stockProvider).valueOrNull ?? const <Stock>[];
  return <String>{
    for (final s in todos)
      if (s.categoria != null && s.categoria!.isNotEmpty) s.categoria!,
  }.toList()..sort();
});

final marcasDelStockProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(stockProvider).valueOrNull ?? const <Stock>[];
  return <String>{
    for (final s in todos)
      if (s.marca != null && s.marca!.isNotEmpty) s.marca!,
  }.toList()..sort();
});

final stockFiltradoProvider = Provider.autoDispose<List<Stock>>((ref) {
  final todos = ref.watch(stockProvider).valueOrNull ?? const <Stock>[];
  final texto = ref.watch(busquedaStockProvider).trim().toLowerCase();
  final filtro = ref.watch(filtroStockProvider);
  final categoria = ref.watch(categoriaStockProvider);
  final marca = ref.watch(marcaStockProvider);

  return todos
      .where(
        (s) => switch (filtro) {
          FiltroStock.todos => true,
          FiltroStock.bajoMinimo => s.bajoMinimo,
          FiltroStock.sinStock => s.stock <= 0,
          FiltroStock.conStock => s.stock > 0,
        },
      )
      .where((s) => categoria == null || s.categoria == categoria)
      .where((s) => marca == null || s.marca == marca)
      .where((s) => texto.isEmpty || s.buscable.contains(texto))
      .toList();
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

/// Que movimientos se miran. La reserva es su propio caso: no es entrada ni
/// salida, es mercaderia apartada que todavia no se movio.
enum FiltroKardex { todos, entradas, salidas, reservas }

final filtroKardexProvider = StateProvider.autoDispose(
  (ref) => FiltroKardex.todos,
);
final motivoKardexFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosKardexActivosProvider = Provider.autoDispose((ref) {
  var n = ref.watch(filtroKardexProvider) == FiltroKardex.todos ? 0 : 1;
  if (ref.watch(motivoKardexFiltroProvider) != null) n++;
  return n;
});

/// Motivos que existen en lo ya traído, para armar el filtro sin listas fijas.
final motivosDelKardexProvider = Provider.autoDispose<List<String>>((ref) {
  final todos =
      ref.watch(kardexProvider).valueOrNull ?? const <MovimientoKardex>[];
  return <String>{for (final k in todos) k.motivo}.toList()..sort();
});

final kardexFiltradoProvider = Provider.autoDispose<List<MovimientoKardex>>((
  ref,
) {
  final todos =
      ref.watch(kardexProvider).valueOrNull ?? const <MovimientoKardex>[];
  final texto = ref.watch(busquedaKardexProvider).trim().toLowerCase();
  final filtro = ref.watch(filtroKardexProvider);
  final motivo = ref.watch(motivoKardexFiltroProvider);

  return todos
      .where(
        (k) => switch (filtro) {
          FiltroKardex.todos => true,
          FiltroKardex.entradas => k.esEntrada && !k.esReserva,
          FiltroKardex.salidas => !k.esEntrada && !k.esReserva,
          FiltroKardex.reservas => k.esReserva,
        },
      )
      .where((k) => motivo == null || k.motivo == motivo)
      .where((k) => texto.isEmpty || k.buscable.contains(texto))
      .toList();
});

// --- Lotes y vencimientos ---

final busquedaLotesProvider = StateProvider.autoDispose((ref) => '');

final lotesProvider = FutureProvider.autoDispose<List<Lote>>(
  (ref) => ref.watch(inventarioApiProvider).lotes(),
);

/// Que lotes se miran. Lo urgente es lo vencido y lo que esta por vencer: es
/// mercaderia que hay que rematar o dar de baja antes de que se pierda sola.
enum FiltroLote { todos, vencidos, porVencer, vigentes }

final filtroLoteProvider = StateProvider.autoDispose((ref) => FiltroLote.todos);
final productoLoteFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final almacenLoteFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosLotesActivosProvider = Provider.autoDispose((ref) {
  var n = ref.watch(filtroLoteProvider) == FiltroLote.todos ? 0 : 1;
  if (ref.watch(productoLoteFiltroProvider) != null) n++;
  if (ref.watch(almacenLoteFiltroProvider) != null) n++;
  return n;
});

/// Productos y almacenes que existen en los lotes, para armar el filtro.
final productosDeLotesProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(lotesProvider).valueOrNull ?? const <Lote>[];
  return <String>{for (final l in todos) l.producto}.toList()..sort();
});

final almacenesDeLotesProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(lotesProvider).valueOrNull ?? const <Lote>[];
  return <String>{for (final l in todos) l.almacen}.toList()..sort();
});

final lotesFiltradosProvider = Provider.autoDispose<List<Lote>>((ref) {
  final todos = ref.watch(lotesProvider).valueOrNull ?? const <Lote>[];
  final texto = ref.watch(busquedaLotesProvider).trim().toLowerCase();
  final filtro = ref.watch(filtroLoteProvider);
  final producto = ref.watch(productoLoteFiltroProvider);
  final almacen = ref.watch(almacenLoteFiltroProvider);

  return todos
      .where(
        (l) => switch (filtro) {
          FiltroLote.todos => true,
          FiltroLote.vencidos => l.vencido,
          FiltroLote.porVencer => l.porVencer,
          FiltroLote.vigentes => !l.vencido && !l.porVencer,
        },
      )
      .where((l) => producto == null || l.producto == producto)
      .where((l) => almacen == null || l.almacen == almacen)
      .where((l) => texto.isEmpty || l.buscable.contains(texto))
      .toList();
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

final almacenRecepcionFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final compraRecepcionFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final recepcionesFiltradasProvider =
    Provider.autoDispose<List<DocumentoInventario>>((ref) {
      final todas =
          ref.watch(recepcionesProvider).valueOrNull ??
          const <DocumentoInventario>[];
      final texto = ref.watch(busquedaRecepcionesProvider).trim().toLowerCase();
      final filtro = ref.watch(filtroDocumentoProvider);
      final almacen = ref.watch(almacenRecepcionFiltroProvider);
      final compra = ref.watch(compraRecepcionFiltroProvider);

      return todas
          .where((d) => pasaDocumento(d.anulado, filtro))
          .where((d) => almacen == null || d.almacen == almacen)
          .where((d) => compra == null || d.compra == compra)
          .where((d) => texto.isEmpty || d.buscable.contains(texto))
          .toList();
    });

final filtrosRecepcionesActivosProvider = Provider.autoDispose((ref) {
  var n = ref.watch(filtroDocumentoProvider) == FiltroDocumento.todos ? 0 : 1;
  if (ref.watch(almacenRecepcionFiltroProvider) != null) n++;
  if (ref.watch(compraRecepcionFiltroProvider) != null) n++;
  return n;
});

/// Compras que existen en las recepciones, para armar el filtro.
final comprasDeRecepcionesProvider = Provider.autoDispose<List<String>>((ref) {
  final todas =
      ref.watch(recepcionesProvider).valueOrNull ??
      const <DocumentoInventario>[];
  return <String>{
    for (final d in todas)
      if (d.compra != null && d.compra!.isNotEmpty) d.compra!,
  }.toList()..sort();
});

// --- Motivos ---

final busquedaMotivosProvider = StateProvider.autoDispose((ref) => '');

class MotivosControlador extends AsyncNotifier<List<Motivo>> {
  @override
  Future<List<Motivo>> build() => ref.watch(inventarioApiProvider).motivos();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(inventarioApiProvider).motivos(),
    );
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

/// De donde sale el motivo: lo puso el usuario o viene con el sistema.
enum FiltroOrigen { todos, manuales, delSistema }

/// Si suma o resta stock.
enum FiltroMovimiento { todos, entradas, salidas }

final origenMotivoProvider = StateProvider.autoDispose(
  (ref) => FiltroOrigen.todos,
);
final tipoMotivoProvider = StateProvider.autoDispose(
  (ref) => FiltroMovimiento.todos,
);

final filtrosMotivosActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(origenMotivoProvider) != FiltroOrigen.todos) n++;
  if (ref.watch(tipoMotivoProvider) != FiltroMovimiento.todos) n++;
  if (ref.watch(estadoFiltroProvider) != FiltroEstado.activos) n++;
  return n;
});

final motivosFiltradosProvider = Provider.autoDispose<List<Motivo>>((ref) {
  final todos = ref.watch(motivosProvider).valueOrNull ?? const <Motivo>[];
  final texto = ref.watch(busquedaMotivosProvider).trim().toLowerCase();
  /*
   * Los del sistema tambien se listan, como en la web.
   *
   * Recepcion de compra, venta, venta anulada... no se editan ni se borran,
   * pero se ven: son los que explican la mayoria de las filas del kardex y
   * esconderlos hacia parecer que el kardex inventaba motivos. Van despues de
   * los manuales, que son los que el usuario si administra.
   */
  final origen = ref.watch(origenMotivoProvider);
  final tipo = ref.watch(tipoMotivoProvider);
  final estado = ref.watch(estadoFiltroProvider);

  final visibles =
      todos
          .where(
            (m) => switch (origen) {
              FiltroOrigen.todos => true,
              FiltroOrigen.manuales => !m.delSistema,
              FiltroOrigen.delSistema => m.delSistema,
            },
          )
          .where(
            (m) => switch (tipo) {
              FiltroMovimiento.todos => true,
              FiltroMovimiento.entradas => m.esEntrada,
              FiltroMovimiento.salidas => !m.esEntrada,
            },
          )
          // Los del sistema nunca se desactivan, asi que el filtro de estado
          // no los toca: si no, pedir "inactivos" los borraria a todos de la
          // lista sin que el usuario haya hecho nada raro.
          .where((m) => m.delSistema || pasaEstado(m.activo, estado))
          .where((m) => texto.isEmpty || m.buscable.contains(texto))
          .toList()
        ..sort((a, b) {
          final porOrigen = (a.delSistema ? 1 : 0) - (b.delSistema ? 1 : 0);
          return porOrigen != 0 ? porOrigen : a.nombre.compareTo(b.nombre);
        });
  return visibles;
});

// --- Ajustes ---

final busquedaAjustesProvider = StateProvider.autoDispose((ref) => '');

class AjustesControlador extends AsyncNotifier<List<DocumentoInventario>> {
  @override
  Future<List<DocumentoInventario>> build() =>
      ref.watch(inventarioApiProvider).ajustes();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(inventarioApiProvider).ajustes(),
    );
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

/// Motivo por el que se filtra el listado de ajustes. Null es "todos".
///
/// Es el filtro que se pide de verdad aqui: no se busca "un ajuste", se busca
/// "las mermas del mes" o "lo que entro por donacion".
final motivoAjusteFiltroProvider = StateProvider.autoDispose<int?>(
  (ref) => null,
);
final almacenAjusteFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosAjustesActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(filtroDocumentoProvider) != FiltroDocumento.todos) n++;
  if (ref.watch(motivoAjusteFiltroProvider) != null) n++;
  if (ref.watch(almacenAjusteFiltroProvider) != null) n++;
  return n;
});

final ajustesFiltradosProvider =
    Provider.autoDispose<List<DocumentoInventario>>((ref) {
      final todos =
          ref.watch(ajustesProvider).valueOrNull ??
          const <DocumentoInventario>[];
      final texto = ref.watch(busquedaAjustesProvider).trim().toLowerCase();
      final filtro = ref.watch(filtroDocumentoProvider);
      final motivoId = ref.watch(motivoAjusteFiltroProvider);
      final almacen = ref.watch(almacenAjusteFiltroProvider);

      return todos
          .where((d) => pasaDocumento(d.anulado, filtro))
          .where((d) => motivoId == null || d.motivoId == motivoId)
          .where((d) => almacen == null || d.almacen == almacen)
          .where((d) => texto.isEmpty || d.buscable.contains(texto))
          .toList();
    });

// --- Transferencias ---

final busquedaTransferenciasProvider = StateProvider.autoDispose((ref) => '');

class TransferenciasControlador
    extends AsyncNotifier<List<DocumentoInventario>> {
  @override
  Future<List<DocumentoInventario>> build() =>
      ref.watch(inventarioApiProvider).transferencias();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(inventarioApiProvider).transferencias(),
    );
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

final deAlmacenTransferenciaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final aAlmacenTransferenciaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final transferenciasFiltradasProvider =
    Provider.autoDispose<List<DocumentoInventario>>((ref) {
      final todos =
          ref.watch(transferenciasProvider).valueOrNull ??
          const <DocumentoInventario>[];
      final texto = ref
          .watch(busquedaTransferenciasProvider)
          .trim()
          .toLowerCase();
      final filtro = ref.watch(filtroDocumentoProvider);
      final de = ref.watch(deAlmacenTransferenciaFiltroProvider);
      final a = ref.watch(aAlmacenTransferenciaFiltroProvider);

      return todos
          .where((d) => pasaDocumento(d.anulado, filtro))
          .where((d) => de == null || d.almacen == de)
          .where((d) => a == null || d.almacenDestino == a)
          .where((d) => texto.isEmpty || d.buscable.contains(texto))
          .toList();
    });

final filtrosTransferenciasActivosProvider = Provider.autoDispose((ref) {
  var n = ref.watch(filtroDocumentoProvider) == FiltroDocumento.todos ? 0 : 1;
  if (ref.watch(deAlmacenTransferenciaFiltroProvider) != null) n++;
  if (ref.watch(aAlmacenTransferenciaFiltroProvider) != null) n++;
  return n;
});

// --- Prestamos ---

final busquedaPrestamosProvider = StateProvider.autoDispose((ref) => '');

class PrestamosControlador extends AsyncNotifier<List<Prestamo>> {
  @override
  Future<List<Prestamo>> build() =>
      ref.watch(inventarioApiProvider).prestamos();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(inventarioApiProvider).prestamos(),
    );
  }

  Future<void> crear(Map<String, dynamic> cuerpo) async {
    await ref.read(inventarioApiProvider).crearPrestamo(cuerpo);
    await recargar();
  }

  Future<void> devolver(int id, Map<String, dynamic> cuerpo) async {
    await ref.read(inventarioApiProvider).registrarDevolucion(id, cuerpo);
    await recargar();
  }

  /// Anula una devolución registrada por error. El id es el del documento de
  /// la devolución, no el del préstamo.
  Future<void> anularDevolucion(int devolucionId) async {
    await ref.read(inventarioApiProvider).anularDevolucionPrestamo(devolucionId);
    await recargar();
  }

  /// Trae un préstamo al día y lo deja también en la lista, para que una
  /// hoja que muestra su detalle (la de devoluciones) se refresque sin cerrar.
  Future<Prestamo> refrescarUno(int id) async {
    final fresco = await ref.read(inventarioApiProvider).prestamo(id);
    state = state.whenData(
      (lista) => [for (final p in lista) if (p.id == id) fresco else p],
    );
    return fresco;
  }
}

final prestamosProvider =
    AsyncNotifierProvider<PrestamosControlador, List<Prestamo>>(
      PrestamosControlador.new,
    );

/// De que lado esta el prestamo: lo que salio del almacen o lo que entro.
enum FiltroPrestamo { todos, prestados, recibidos }

/// Si ya volvio o sigue afuera. Lo pendiente es lo que hay que perseguir.
enum FiltroDevolucion { todos, pendientes, devueltos }

final filtroPrestamoProvider = StateProvider.autoDispose(
  (ref) => FiltroPrestamo.todos,
);
final filtroDevolucionProvider = StateProvider.autoDispose(
  (ref) => FiltroDevolucion.todos,
);
final almacenPrestamoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosPrestamosActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(filtroPrestamoProvider) != FiltroPrestamo.todos) n++;
  if (ref.watch(filtroDevolucionProvider) != FiltroDevolucion.todos) n++;
  if (ref.watch(almacenPrestamoFiltroProvider) != null) n++;
  return n;
});

final prestamosFiltradosProvider = Provider.autoDispose<List<Prestamo>>((ref) {
  final todos = ref.watch(prestamosProvider).valueOrNull ?? const <Prestamo>[];
  final texto = ref.watch(busquedaPrestamosProvider).trim().toLowerCase();
  final lado = ref.watch(filtroPrestamoProvider);
  final devolucion = ref.watch(filtroDevolucionProvider);
  final almacen = ref.watch(almacenPrestamoFiltroProvider);

  return todos
      .where(
        (p) => switch (lado) {
          FiltroPrestamo.todos => true,
          FiltroPrestamo.prestados => p.esDado,
          FiltroPrestamo.recibidos => !p.esDado,
        },
      )
      .where(
        (p) => switch (devolucion) {
          FiltroDevolucion.todos => true,
          FiltroDevolucion.pendientes => p.estado == EstadoPrestamo.pendiente,
          FiltroDevolucion.devueltos => p.estado != EstadoPrestamo.pendiente,
        },
      )
      .where((p) => almacen == null || p.almacen == almacen)
      .where((p) => texto.isEmpty || p.buscable.contains(texto))
      .toList();
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
