import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/flota.dart';
import '../datos/flota_api.dart';
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

// --- Flota y conductores ---

final flotaApiProvider = Provider((ref) => FlotaApi(ref.watch(clienteApiProvider)));

final busquedaVehiculosProvider = StateProvider.autoDispose((ref) => '');
final busquedaConductoresProvider = StateProvider.autoDispose((ref) => '');

/// Listado de vehículos.
class VehiculosControlador extends AsyncNotifier<List<Vehiculo>> {
  @override
  Future<List<Vehiculo>> build() => ref.watch(flotaApiProvider).vehiculos();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(flotaApiProvider).vehiculos());
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(flotaApiProvider);
    if (id == null) {
      await api.crearVehiculo(cuerpo);
    } else {
      await api.actualizarVehiculo(id, cuerpo);
    }
    await recargar();
  }

  Future<void> eliminar(int id) async {
    await ref.read(flotaApiProvider).eliminarVehiculo(id);
    await recargar();
  }
}

final vehiculosProvider = AsyncNotifierProvider<VehiculosControlador, List<Vehiculo>>(
  VehiculosControlador.new,
);

final vehiculosFiltradosProvider = Provider.autoDispose<List<Vehiculo>>((ref) {
  final todos = ref.watch(vehiculosProvider).valueOrNull ?? const <Vehiculo>[];
  final texto = ref.watch(busquedaVehiculosProvider).trim().toLowerCase();
  return todos.where((v) => texto.isEmpty || v.buscable.contains(texto)).toList();
});

final resumenFlotaProvider = FutureProvider.autoDispose<ResumenFlota>((ref) {
  // Se ata al listado: tras guardar o borrar, los totales se rehacen solos en
  // vez de quedarse contando lo de antes.
  ref.watch(vehiculosProvider);
  return ref.watch(flotaApiProvider).resumenFlota();
});

/// Tipos de vehículo: el catálogo del que salen los vehículos.
class TiposVehiculoControlador extends AsyncNotifier<List<TipoVehiculo>> {
  @override
  Future<List<TipoVehiculo>> build() => ref.watch(flotaApiProvider).tipos();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(flotaApiProvider).tipos());
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(flotaApiProvider);
    if (id == null) {
      await api.crearTipo(cuerpo);
    } else {
      await api.actualizarTipo(id, cuerpo);
    }
    await recargar();
  }

  Future<void> eliminar(int id) async {
    await ref.read(flotaApiProvider).eliminarTipo(id);
    await recargar();
  }
}

final tiposVehiculoProvider =
    AsyncNotifierProvider<TiposVehiculoControlador, List<TipoVehiculo>>(
      TiposVehiculoControlador.new,
    );

/// Tipos activos, para el selector del formulario de vehículo.
final tiposVehiculoActivosProvider = Provider.autoDispose<List<TipoVehiculo>>(
  (ref) => (ref.watch(tiposVehiculoProvider).valueOrNull ?? const <TipoVehiculo>[])
      .where((t) => t.activo)
      .toList(),
);

/// Listado de conductores.
class ConductoresControlador extends AsyncNotifier<List<Conductor>> {
  @override
  Future<List<Conductor>> build() => ref.watch(flotaApiProvider).conductores();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(flotaApiProvider).conductores());
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(flotaApiProvider);
    if (id == null) {
      await api.crearConductor(cuerpo);
    } else {
      await api.actualizarConductor(id, cuerpo);
    }
    await recargar();
  }

  Future<void> eliminar(int id) async {
    await ref.read(flotaApiProvider).eliminarConductor(id);
    await recargar();
  }
}

final conductoresProvider = AsyncNotifierProvider<ConductoresControlador, List<Conductor>>(
  ConductoresControlador.new,
);

final conductoresFiltradosProvider = Provider.autoDispose<List<Conductor>>((ref) {
  final todos = ref.watch(conductoresProvider).valueOrNull ?? const <Conductor>[];
  final texto = ref.watch(busquedaConductoresProvider).trim().toLowerCase();
  return todos.where((c) => texto.isEmpty || c.buscable.contains(texto)).toList();
});

/// Conductores activos, para asignarlos a un vehículo.
final conductoresActivosProvider = Provider.autoDispose<List<Conductor>>(
  (ref) => (ref.watch(conductoresProvider).valueOrNull ?? const <Conductor>[])
      .where((c) => c.activo)
      .toList(),
);

final resumenConductoresProvider = FutureProvider.autoDispose<ResumenConductores>((ref) {
  ref.watch(conductoresProvider);
  return ref.watch(flotaApiProvider).resumenConductores();
});
