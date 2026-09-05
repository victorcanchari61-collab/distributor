import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/auditoria.dart';
import 'config_controlador.dart';

final busquedaAuditoriaProvider = StateProvider.autoDispose((ref) => '');

/// Null = todas las acciones.
final accionAuditoriaFiltroProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Solo lectura: los registros los deja el backend al guardar cualquier dato.
class AuditoriaControlador extends AsyncNotifier<List<RegistroAuditoria>> {
  @override
  Future<List<RegistroAuditoria>> build() => ref.watch(configApiProvider).auditoria();

  Future<void> recargar() async {
    state = await AsyncValue.guard(() => ref.read(configApiProvider).auditoria());
  }
}

final auditoriaProvider =
    AsyncNotifierProvider<AuditoriaControlador, List<RegistroAuditoria>>(
      AuditoriaControlador.new,
    );

final auditoriaFiltradaProvider = Provider.autoDispose<List<RegistroAuditoria>>((ref) {
  final todos = ref.watch(auditoriaProvider).valueOrNull ?? const <RegistroAuditoria>[];
  final texto = ref.watch(busquedaAuditoriaProvider).trim().toLowerCase();
  final accion = ref.watch(accionAuditoriaFiltroProvider);
  return todos
      .where((r) => accion == null || r.accion == accion)
      .where((r) => texto.isEmpty || r.buscable.contains(texto))
      .toList();
});
