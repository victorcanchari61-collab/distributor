import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/mercado.dart';
import '../datos/ruta.dart';
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

final busquedaRutasProvider = StateProvider.autoDispose((ref) => '');

/// Listado de rutas.
class RutasControlador extends AsyncNotifier<List<Ruta>> {
  @override
  Future<List<Ruta>> build() => ref.watch(tmsApiProvider).rutas();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(tmsApiProvider).rutas());
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(tmsApiProvider);
    if (id == null) {
      await api.crearRuta(cuerpo);
    } else {
      await api.actualizarRuta(id, cuerpo);
    }
    await recargar();
  }

  Future<void> cambiarEstado(Ruta ruta) async {
    await ref.read(tmsApiProvider).actualizarRuta(ruta.id, {
      'nombre': ruta.nombre,
      'activo': !ruta.activo,
    });
    await recargar();
  }

  Future<void> eliminar(int id) async {
    await ref.read(tmsApiProvider).eliminarRuta(id);
    await recargar();
  }
}

final rutasProvider = AsyncNotifierProvider<RutasControlador, List<Ruta>>(
  RutasControlador.new,
);

final rutasFiltradasProvider = Provider.autoDispose<List<Ruta>>((ref) {
  final todas = ref.watch(rutasProvider).valueOrNull ?? const <Ruta>[];
  final texto = ref.watch(busquedaRutasProvider).trim().toLowerCase();
  return todas.where((r) => texto.isEmpty || r.buscable.contains(texto)).toList();
});

/// Rutas activas, para el selector del formulario de Clientes.
final rutasActivasProvider = Provider.autoDispose<List<Ruta>>(
  (ref) => (ref.watch(rutasProvider).valueOrNull ?? const <Ruta>[])
      .where((r) => r.activo)
      .toList(),
);
