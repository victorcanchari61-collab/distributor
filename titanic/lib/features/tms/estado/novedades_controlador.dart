import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/estado/filtro_estado.dart';
import '../../auth/estado/auth_controlador.dart';
import '../datos/novedad.dart';
import '../datos/novedad_api.dart';

final novedadApiProvider = Provider((ref) => NovedadApi(ref.watch(clienteApiProvider)));

// --- Motivos ---

final busquedaMotivosProvider = StateProvider.autoDispose((ref) => '');

/// El catálogo de motivos, para quien lo administra.
class MotivosNovedadControlador extends AsyncNotifier<List<MotivoNovedad>> {
  @override
  Future<List<MotivoNovedad>> build() => ref.watch(novedadApiProvider).motivos();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(novedadApiProvider).motivos());
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(novedadApiProvider);
    if (id == null) {
      await api.crearMotivo(cuerpo);
    } else {
      await api.actualizarMotivo(id, cuerpo);
    }
    await recargar();
  }

  Future<void> cambiarEstado(MotivoNovedad motivo) async {
    await ref.read(novedadApiProvider).actualizarMotivo(motivo.id, {
      'nombre': motivo.nombre,
      'descripcion': motivo.descripcion,
      'regresaAlAlmacen': motivo.regresaAlAlmacen,
      'activo': !motivo.activo,
    });
    await recargar();
  }
}

final motivosNovedadProvider =
    AsyncNotifierProvider<MotivosNovedadControlador, List<MotivoNovedad>>(
      MotivosNovedadControlador.new,
    );

final filtrosMotivosActivosProvider = Provider.autoDispose(
  (ref) => ref.watch(estadoFiltroProvider) == FiltroEstado.activos ? 0 : 1,
);

final motivosNovedadFiltradosProvider = Provider.autoDispose<List<MotivoNovedad>>((ref) {
  final todos = ref.watch(motivosNovedadProvider).valueOrNull ?? const <MotivoNovedad>[];
  final texto = ref.watch(busquedaMotivosProvider).trim().toLowerCase();
  final estado = ref.watch(estadoFiltroProvider);

  return todos
      .where((m) => pasaEstado(m.activo, estado))
      .where((m) => texto.isEmpty || m.buscable.contains(texto))
      .toList();
});

/// Los motivos activos, para elegir al entregar un pedido.
///
/// Va por la ruta de "opciones" y no por el catálogo: quien entrega puede
/// tener permiso de convertir pedidos sin poder ver ni editar los motivos.
final opcionesMotivoProvider = FutureProvider.autoDispose<List<MotivoNovedad>>(
  (ref) => ref.watch(novedadApiProvider).opciones(),
);

// --- Novedades ---

final busquedaNovedadesProvider = StateProvider.autoDispose((ref) => '');

/// Filtros propios de novedades. Null es "todos".
final estadoNovedadFiltroProvider = StateProvider.autoDispose<String?>((ref) => null);
final motivoNovedadFiltroProvider = StateProvider.autoDispose<String?>((ref) => null);
final tipoNovedadFiltroProvider = StateProvider.autoDispose<String?>((ref) => null);

final filtrosNovedadesActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(estadoNovedadFiltroProvider) != null) n++;
  if (ref.watch(motivoNovedadFiltroProvider) != null) n++;
  if (ref.watch(tipoNovedadFiltroProvider) != null) n++;
  return n;
});

/// Lo que no se entregó completo, de la más nueva a la más vieja.
class NovedadesControlador extends AsyncNotifier<List<Novedad>> {
  @override
  Future<List<Novedad>> build() => ref.watch(novedadApiProvider).novedades();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(novedadApiProvider).novedades());
  }

  /// El encargado cuenta lo que volvió: llegó completo (RECIBIDA) o faltó algo.
  Future<void> verificar(int id, Map<String, dynamic> cuerpo) async {
    await ref.read(novedadApiProvider).verificar(id, cuerpo);
    await recargar();
  }

  Future<void> reabrir(int id) async {
    await ref.read(novedadApiProvider).reabrir(id);
    await recargar();
  }
}

final novedadesProvider = AsyncNotifierProvider<NovedadesControlador, List<Novedad>>(
  NovedadesControlador.new,
);

final resumenNovedadesProvider = FutureProvider.autoDispose<ResumenNovedades>((ref) {
  // Atado al listado: al revisar una novedad, los contadores se rehacen solos.
  ref.watch(novedadesProvider);
  return ref.watch(novedadApiProvider).resumen();
});

/// Los motivos que de verdad aparecen en las novedades, para armar el filtro.
final motivosDeNovedadesProvider = Provider.autoDispose<List<String>>((ref) {
  final todas = ref.watch(novedadesProvider).valueOrNull ?? const <Novedad>[];
  return <String>{for (final n in todas) n.motivo}.toList()..sort();
});

/// La búsqueda y los filtros de la pantalla, dichos como los entiende el
/// servidor: la consulta de la tabla, con columna, operador y valor.
///
/// Sirve para pedir el reporte en PDF con exactamente lo que se ve en la lista.
/// El orden no viaja: el natural del servidor es el mismo de la pantalla, de la
/// más nueva a la más vieja. Sin filtro de estado el servidor también deja
/// fuera las anuladas, igual que [novedadesFiltradasProvider].
final consultaNovedadesProvider = Provider.autoDispose<Map<String, dynamic>>((ref) {
  final estado = ref.watch(estadoNovedadFiltroProvider);
  final motivo = ref.watch(motivoNovedadFiltroProvider);
  final tipo = ref.watch(tipoNovedadFiltroProvider);

  Map<String, String> igual(String columna, String valor) => {
    'columna': columna,
    'operador': 'equals',
    'valor': valor,
  };

  return {
    'buscar': ref.watch(busquedaNovedadesProvider).trim(),
    'filtros': [
      if (estado != null) igual('estado', estado),
      if (motivo != null) igual('motivo', motivo),
      if (tipo != null) igual('tipo', tipo),
    ],
  };
});

final novedadesFiltradasProvider = Provider.autoDispose<List<Novedad>>((ref) {
  final todas = ref.watch(novedadesProvider).valueOrNull ?? const <Novedad>[];
  final texto = ref.watch(busquedaNovedadesProvider).trim().toLowerCase();
  final estado = ref.watch(estadoNovedadFiltroProvider);
  final motivo = ref.watch(motivoNovedadFiltroProvider);
  final tipo = ref.watch(tipoNovedadFiltroProvider);

  return todas
      // Las anuladas no cuentan: solo salen si se piden expresamente.
      .where((n) => estado == null ? n.estado != EstadoNovedad.anulada : n.estado == estado)
      .where((n) => motivo == null || n.motivo == motivo)
      .where((n) => tipo == null || n.tipo == tipo)
      .where((n) => texto.isEmpty || n.buscable.contains(texto))
      .toList();
});
