import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/auditoria.dart';
import 'config_controlador.dart';

final busquedaAuditoriaProvider = StateProvider.autoDispose((ref) => '');

/// Null = todas las acciones.
final accionAuditoriaFiltroProvider = StateProvider.autoDispose<String?>((ref) => null);
final usuarioAuditoriaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final entidadAuditoriaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

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
  final usuario = ref.watch(usuarioAuditoriaFiltroProvider);
  final entidad = ref.watch(entidadAuditoriaFiltroProvider);
  return todos
      .where((r) => accion == null || r.accion == accion)
      .where((r) => usuario == null || r.usuario == usuario)
      .where((r) => entidad == null || r.entidad == entidad)
      .where((r) => texto.isEmpty || r.buscable.contains(texto))
      .toList();
});

/// Usuarios y entidades que existen en el registro, para armar el filtro.
final usuariosAuditoriaProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(auditoriaProvider).valueOrNull ?? const <RegistroAuditoria>[];
  return <String>{for (final r in todos) r.usuario}.toList()..sort();
});

final entidadesAuditoriaProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(auditoriaProvider).valueOrNull ?? const <RegistroAuditoria>[];
  return <String>{for (final r in todos) r.entidad}.toList()..sort();
});
