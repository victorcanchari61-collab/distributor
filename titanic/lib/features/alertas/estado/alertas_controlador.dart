import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/alerta.dart';
import '../datos/alertas_api.dart';
import '../datos/alertas_leidas.dart';

final alertasApiProvider = Provider(
  (ref) => AlertasApi(ref.watch(clienteApiProvider)),
);

/// La app movil no tiene conexion en tiempo real como el panel web: se
/// refresca sola cada minuto mientras la campana este montada, para que igual
/// se sienta viva sin depender de que el usuario recargue a mano.
class AlertasControlador extends AsyncNotifier<List<Alerta>> {
  Timer? _temporizador;

  @override
  Future<List<Alerta>> build() async {
    _temporizador?.cancel();
    _temporizador = Timer.periodic(
      const Duration(minutes: 1),
      (_) => recargar(),
    );
    ref.onDispose(() => _temporizador?.cancel());

    return ref.watch(alertasApiProvider).alertas();
  }

  Future<void> recargar() async {
    state = await AsyncValue.guard(
      () => ref.read(alertasApiProvider).alertas(),
    );
  }
}

final alertasProvider = AsyncNotifierProvider<AlertasControlador, List<Alerta>>(
  AlertasControlador.new,
);

/// Ids de alertas ya marcadas como leidas, por dispositivo.
///
/// Vive aparte de `AlertasControlador`: las alertas se recalculan solas cada
/// minuto, pero lo leido no cambia por eso — solo cuando se marca algo.
class AlertasLeidasControlador extends AsyncNotifier<Map<String, DateTime>> {
  final _almacen = const AlertasLeidasAlmacen();

  @override
  Future<Map<String, DateTime>> build() => _almacen.leidas();

  Future<void> marcar(String id) async {
    await _almacen.marcar(id);
    state = AsyncValue.data({...state.valueOrNull ?? {}, id: DateTime.now()});
  }

  Future<void> marcarTodas(List<String> ids) async {
    await _almacen.marcarTodas(ids);
    final ahora = DateTime.now();
    final actuales = {...state.valueOrNull ?? {}};
    for (final id in ids) {
      actuales[id] = ahora;
    }
    state = AsyncValue.data(actuales);
  }
}

final alertasLeidasProvider =
    AsyncNotifierProvider<AlertasLeidasControlador, Map<String, DateTime>>(
      AlertasLeidasControlador.new,
    );
