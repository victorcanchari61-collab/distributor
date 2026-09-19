import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/consulta_tabla.dart';
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

/// Los registros los deja el backend al guardar cualquier dato: aquí no se
/// anota nada. Lo único que se hace es depurarlos.
class AuditoriaControlador extends AsyncNotifier<List<RegistroAuditoria>> {
  @override
  Future<List<RegistroAuditoria>> build() => ref.watch(configApiProvider).auditoria();

  Future<void> recargar() async {
    state = await AsyncValue.guard(() => ref.read(configApiProvider).auditoria());
  }

  /// Cuántos registros deja a la vista esa consulta.
  Future<int> contar(ConsultaTabla consulta) =>
      ref.read(configApiProvider).contarAuditoria(consulta);

  /// Borra todo lo que esa consulta deja a la vista y devuelve cuántos fueron.
  ///
  /// Refresca aquí y no en la hoja que lo pidió: si se cierra a mitad de
  /// camino, la lista igual queda al día.
  Future<int> depurar(ConsultaTabla consulta) async {
    final eliminados = await ref.read(configApiProvider).depurarAuditoria(consulta);
    ref.invalidate(resumenAuditoriaProvider);
    await recargar();
    return eliminados;
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

/// Contadores y valores de filtro de TODA la bitácora. La lista trae solo los
/// últimos cambios, así que sus usuarios y entidades no alcanzan para elegir
/// qué depurar: pueden faltar los de registros más viejos.
final resumenAuditoriaProvider = FutureProvider.autoDispose<ResumenAuditoria>(
  (ref) => ref.watch(configApiProvider).resumenAuditoria(),
);

/// Usuarios y entidades que existen en el registro, para armar el filtro.
final usuariosAuditoriaProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(auditoriaProvider).valueOrNull ?? const <RegistroAuditoria>[];
  return <String>{for (final r in todos) r.usuario}.toList()..sort();
});

final entidadesAuditoriaProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(auditoriaProvider).valueOrNull ?? const <RegistroAuditoria>[];
  return <String>{for (final r in todos) r.entidad}.toList()..sort();
});
