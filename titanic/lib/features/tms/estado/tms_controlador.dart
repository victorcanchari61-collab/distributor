import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/estado/filtro_estado.dart';
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
}

final mercadosProvider = AsyncNotifierProvider<MercadosControlador, List<Mercado>>(
  MercadosControlador.new,
);

final filtrosMercadosActivosProvider = Provider.autoDispose((ref) {
  var n = ref.watch(estadoFiltroProvider) == FiltroEstado.activos ? 0 : 1;
  if (ref.watch(distritoMercadoProvider) != null) n++;
  if (ref.watch(direccionMercadoProvider) != null) n++;
  return n;
});

/// Los distritos que de verdad tienen mercados, no la lista entera del país.
final distritosDeMercadosProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(mercadosProvider).valueOrNull ?? const <Mercado>[];
  return <String>{
    for (final m in todos)
      if (m.distrito != null && m.distrito!.isNotEmpty) m.distrito!,
  }.toList()..sort();
});

final distritoMercadoProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final direccionMercadoProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// Las direcciones que de verdad tienen mercados, no una lista fija.
final direccionesDeMercadosProvider = Provider.autoDispose<List<String>>((
  ref,
) {
  final todos = ref.watch(mercadosProvider).valueOrNull ?? const <Mercado>[];
  return <String>{
    for (final m in todos)
      if (m.direccion != null && m.direccion!.isNotEmpty) m.direccion!,
  }.toList()..sort();
});

final mercadosFiltradosProvider = Provider.autoDispose<List<Mercado>>((ref) {
  final todos = ref.watch(mercadosProvider).valueOrNull ?? const <Mercado>[];
  final texto = ref.watch(busquedaMercadosProvider).trim().toLowerCase();
  final estado = ref.watch(estadoFiltroProvider);
  final distrito = ref.watch(distritoMercadoProvider);
  final direccion = ref.watch(direccionMercadoProvider);

  return todos
      .where((m) => pasaEstado(m.activo, estado))
      .where((m) => distrito == null || m.distrito == distrito)
      .where((m) => direccion == null || m.direccion == direccion)
      .where((m) => texto.isEmpty || m.buscable.contains(texto))
      .toList();
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
}

final rutasProvider = AsyncNotifierProvider<RutasControlador, List<Ruta>>(
  RutasControlador.new,
);

final filtrosRutasActivosProvider = Provider.autoDispose(
  (ref) => ref.watch(estadoFiltroProvider) == FiltroEstado.activos ? 0 : 1,
);

final rutasFiltradasProvider = Provider.autoDispose<List<Ruta>>((ref) {
  final todas = ref.watch(rutasProvider).valueOrNull ?? const <Ruta>[];
  final texto = ref.watch(busquedaRutasProvider).trim().toLowerCase();
  final estado = ref.watch(estadoFiltroProvider);

  return todas
      .where((r) => pasaEstado(r.activo, estado))
      .where((r) => texto.isEmpty || r.buscable.contains(texto))
      .toList();
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
}

final vehiculosProvider = AsyncNotifierProvider<VehiculosControlador, List<Vehiculo>>(
  VehiculosControlador.new,
);

/// Como andan los papeles. Es el filtro que importa de una flota: un camion
/// con el SOAT vencido no puede salir, por muy activo que este en el sistema.
enum FiltroPapeles { todos, vencidos, porVencer, alDia }

final filtroPapelesProvider = StateProvider.autoDispose(
  (ref) => FiltroPapeles.todos,
);

final tipoVehiculoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final marcaVehiculoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final conductorVehiculoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosVehiculosActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(estadoFiltroProvider) != FiltroEstado.activos) n++;
  if (ref.watch(filtroPapelesProvider) != FiltroPapeles.todos) n++;
  if (ref.watch(tipoVehiculoFiltroProvider) != null) n++;
  if (ref.watch(marcaVehiculoFiltroProvider) != null) n++;
  if (ref.watch(conductorVehiculoFiltroProvider) != null) n++;
  return n;
});

bool pasaPapeles(String estadoDocumentos, FiltroPapeles filtro) =>
    switch (filtro) {
      FiltroPapeles.todos => true,
      FiltroPapeles.vencidos => estadoDocumentos == EstadoVencimiento.vencido,
      FiltroPapeles.porVencer => estadoDocumentos == EstadoVencimiento.porVencer,
      FiltroPapeles.alDia => estadoDocumentos == EstadoVencimiento.alDia,
    };

final vehiculosFiltradosProvider = Provider.autoDispose<List<Vehiculo>>((ref) {
  final todos = ref.watch(vehiculosProvider).valueOrNull ?? const <Vehiculo>[];
  final texto = ref.watch(busquedaVehiculosProvider).trim().toLowerCase();
  final estado = ref.watch(estadoFiltroProvider);
  final papeles = ref.watch(filtroPapelesProvider);
  final tipo = ref.watch(tipoVehiculoFiltroProvider);
  final marca = ref.watch(marcaVehiculoFiltroProvider);
  final conductor = ref.watch(conductorVehiculoFiltroProvider);

  return todos
      .where((v) => pasaEstado(v.activo, estado))
      .where((v) => pasaPapeles(v.estadoDocumentos, papeles))
      .where((v) => tipo == null || v.tipoVehiculo == tipo)
      .where((v) => marca == null || v.marca == marca)
      .where((v) => conductor == null || v.conductor == conductor)
      .where((v) => texto.isEmpty || v.buscable.contains(texto))
      .toList();
});

/// Marcas y conductores que existen en la flota, para armar el filtro.
final marcasVehiculoProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(vehiculosProvider).valueOrNull ?? const <Vehiculo>[];
  final valores =
      todos
          .map((v) => v.marca)
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return valores;
});

final conductoresVehiculoProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(vehiculosProvider).valueOrNull ?? const <Vehiculo>[];
  final valores =
      todos
          .map((v) => v.conductor)
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return valores;
});

final resumenFlotaProvider = FutureProvider.autoDispose<ResumenFlota>((ref) {
  // Se ata al listado: tras guardar o cambiar un estado, los totales se
  // rehacen solos en vez de quedarse contando lo de antes.
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
}

final conductoresProvider = AsyncNotifierProvider<ConductoresControlador, List<Conductor>>(
  ConductoresControlador.new,
);

final filtrosConductoresActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(estadoFiltroProvider) != FiltroEstado.activos) n++;
  if (ref.watch(filtroPapelesProvider) != FiltroPapeles.todos) n++;
  return n;
});

final conductoresFiltradosProvider = Provider.autoDispose<List<Conductor>>((ref) {
  final todos = ref.watch(conductoresProvider).valueOrNull ?? const <Conductor>[];
  final texto = ref.watch(busquedaConductoresProvider).trim().toLowerCase();
  final estado = ref.watch(estadoFiltroProvider);
  final papeles = ref.watch(filtroPapelesProvider);

  return todos
      .where((c) => pasaEstado(c.activo, estado))
      .where((c) => pasaPapeles(c.estadoDocumentos, papeles))
      .where((c) => texto.isEmpty || c.buscable.contains(texto))
      .toList();
});

/// Conductores activos, para asignarlos a un vehículo.
final conductoresActivosProvider = Provider.autoDispose<List<Conductor>>(
  (ref) => (ref.watch(conductoresProvider).valueOrNull ?? const <Conductor>[])
      .where((c) => c.activo)
      .toList(),
);

/// Vehículos activos, para elegir el camión de un despacho.
final vehiculosActivosProvider = Provider.autoDispose<List<Vehiculo>>(
  (ref) => (ref.watch(vehiculosProvider).valueOrNull ?? const <Vehiculo>[])
      .where((v) => v.activo)
      .toList(),
);

final resumenConductoresProvider = FutureProvider.autoDispose<ResumenConductores>((ref) {
  ref.watch(conductoresProvider);
  return ref.watch(flotaApiProvider).resumenConductores();
});
