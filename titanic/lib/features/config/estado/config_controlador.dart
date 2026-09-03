import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/config_api.dart';
import '../datos/config_modelos.dart';

final configApiProvider = Provider(
  (ref) => ConfigApi(ref.watch(clienteApiProvider)),
);

/// Texto del buscador de cada listado.
final busquedaUsuariosProvider = StateProvider.autoDispose((ref) => '');
final busquedaRolesProvider = StateProvider.autoDispose((ref) => '');
final busquedaEmpresasProvider = StateProvider.autoDispose((ref) => '');

// --- Usuarios ---

class UsuariosControlador extends AsyncNotifier<List<Usuario>> {
  @override
  Future<List<Usuario>> build() => ref.watch(configApiProvider).usuarios();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(configApiProvider).usuarios(),
    );
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(configApiProvider);
    if (id == null) {
      await api.crearUsuario(cuerpo);
    } else {
      await api.actualizarUsuario(id, cuerpo);
    }
    await recargar();
  }

  /// Activa o desactiva. El backend no tiene un PATCH de estado para usuarios:
  /// se reenvia el usuario completo con el `activo` cambiado.
  Future<void> cambiarEstado(Usuario usuario) async {
    await ref.read(configApiProvider).actualizarUsuario(usuario.id, {
      'nombre': usuario.nombre,
      'email': usuario.email,
      'dni': usuario.dni,
      'rolId': usuario.rolId,
      'activo': !usuario.activo,
    });
    await recargar();
  }
}

final usuariosProvider =
    AsyncNotifierProvider<UsuariosControlador, List<Usuario>>(
      UsuariosControlador.new,
    );

final usuariosFiltradosProvider = Provider.autoDispose<List<Usuario>>((ref) {
  final todos = ref.watch(usuariosProvider).valueOrNull ?? const <Usuario>[];
  final texto = ref.watch(busquedaUsuariosProvider).trim().toLowerCase();
  if (texto.isEmpty) return todos;
  return todos.where((u) => u.buscable.contains(texto)).toList();
});

// --- Roles ---

class RolesControlador extends AsyncNotifier<List<Rol>> {
  @override
  Future<List<Rol>> build() => ref.watch(configApiProvider).roles();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(configApiProvider).roles());
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(configApiProvider);
    if (id == null) {
      await api.crearRol(cuerpo);
    } else {
      await api.actualizarRol(id, cuerpo);
    }
    await recargar();
  }

  Future<void> cambiarEstado(Rol rol) async {
    await ref.read(configApiProvider).actualizarRol(rol.id, {
      'nombre': rol.nombre,
      'descripcion': rol.descripcion,
      'activo': !rol.activo,
    });
    await recargar();
  }

  Future<void> guardarPermisos(int rolId, List<RolPermiso> permisos) async {
    await ref
        .read(configApiProvider)
        .actualizarPermisos(rolId, [for (final p in permisos) p.aCuerpo()]);
    await recargar();
  }
}

final rolesProvider = AsyncNotifierProvider<RolesControlador, List<Rol>>(
  RolesControlador.new,
);

final rolesFiltradosProvider = Provider.autoDispose<List<Rol>>((ref) {
  final todos = ref.watch(rolesProvider).valueOrNull ?? const <Rol>[];
  final texto = ref.watch(busquedaRolesProvider).trim().toLowerCase();
  if (texto.isEmpty) return todos;
  return todos.where((r) => r.buscable.contains(texto)).toList();
});

/// Roles activos, para el selector del formulario de usuario.
final rolesActivosProvider = Provider.autoDispose<List<Rol>>((ref) {
  final todos = ref.watch(rolesProvider).valueOrNull ?? const <Rol>[];
  return todos.where((r) => r.activo).toList();
});

// --- Empresas ---

class EmpresasControlador extends AsyncNotifier<List<Empresa>> {
  @override
  Future<List<Empresa>> build() => ref.watch(configApiProvider).empresas();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(configApiProvider).empresas(),
    );
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(configApiProvider);
    if (id == null) {
      await api.crearEmpresa(cuerpo);
    } else {
      await api.actualizarEmpresa(id, cuerpo);
    }
    await recargar();
  }

  /// Deja esta empresa como la que opera el sistema.
  Future<void> activar(Empresa empresa) async {
    await ref.read(configApiProvider).activarEmpresa(empresa.id);
    await recargar();
  }

  Future<void> cambiarHabilitacion(Empresa empresa) async {
    await ref
        .read(configApiProvider)
        .cambiarHabilitacion(empresa.id, habilitada: !empresa.habilitada);
    await recargar();
  }
}

final empresasProvider =
    AsyncNotifierProvider<EmpresasControlador, List<Empresa>>(
      EmpresasControlador.new,
    );

final empresasFiltradasProvider = Provider.autoDispose<List<Empresa>>((ref) {
  final todas = ref.watch(empresasProvider).valueOrNull ?? const <Empresa>[];
  final texto = ref.watch(busquedaEmpresasProvider).trim().toLowerCase();
  if (texto.isEmpty) return todas;
  return todas.where((e) => e.buscable.contains(texto)).toList();
});
