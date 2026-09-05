import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/alerta.dart';
import '../datos/alertas_api.dart';

final alertasApiProvider = Provider((ref) => AlertasApi(ref.watch(clienteApiProvider)));

/// La app movil no tiene conexion en tiempo real como el panel web: se
/// refresca sola cada minuto mientras la campana este montada, para que igual
/// se sienta viva sin depender de que el usuario recargue a mano.
class AlertasControlador extends AsyncNotifier<List<Alerta>> {
  Timer? _temporizador;

  @override
  Future<List<Alerta>> build() async {
    _temporizador?.cancel();
    _temporizador = Timer.periodic(const Duration(minutes: 1), (_) => recargar());
    ref.onDispose(() => _temporizador?.cancel());

    return ref.watch(alertasApiProvider).alertas();
  }

  Future<void> recargar() async {
    state = await AsyncValue.guard(() => ref.read(alertasApiProvider).alertas());
  }
}

final alertasProvider = AsyncNotifierProvider<AlertasControlador, List<Alerta>>(
  AlertasControlador.new,
);
