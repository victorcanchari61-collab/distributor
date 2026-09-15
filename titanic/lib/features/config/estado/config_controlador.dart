import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/estado/filtro_estado.dart';
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

// --- Permisos ---

/// El catalogo de submodulos y sus acciones, tal como lo declara el backend.
///
/// Se pide una vez y no cambia en caliente: es la forma del sistema, no datos.
final catalogoPermisosProvider = FutureProvider<List<SubmoduloCatalogo>>(
  (ref) => ref.watch(configApiProvider).catalogoPermisos(),
);

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

/// Rol por el que se filtra. Null es "todos".
final rolFiltroProvider = StateProvider.autoDispose<int?>((ref) => null);

final filtrosUsuariosActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(estadoFiltroProvider) != FiltroEstado.activos) n++;
  if (ref.watch(rolFiltroProvider) != null) n++;
  return n;
});

final usuariosFiltradosProvider = Provider.autoDispose<List<Usuario>>((ref) {
  final todos = ref.watch(usuariosProvider).valueOrNull ?? const <Usuario>[];
  final texto = ref.watch(busquedaUsuariosProvider).trim().toLowerCase();
  final estado = ref.watch(estadoFiltroProvider);
  final rolId = ref.watch(rolFiltroProvider);

  return todos
      .where((u) => pasaEstado(u.activo, estado))
      .where((u) => rolId == null || u.rolId == rolId)
      .where((u) => texto.isEmpty || u.buscable.contains(texto))
      .toList();
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

  /// Reemplaza los permisos del rol por los de la matriz.
  Future<void> guardarPermisos(int rolId, List<RolPermiso> permisos) async {
    await ref.read(configApiProvider).actualizarPermisos(rolId, [
      for (final p in permisos) p.aCuerpo(),
    ]);
    await recargar();
  }
}

final rolesProvider = AsyncNotifierProvider<RolesControlador, List<Rol>>(
  RolesControlador.new,
);

final filtrosRolesActivosProvider = Provider.autoDispose(
  (ref) => ref.watch(estadoFiltroProvider) == FiltroEstado.activos ? 0 : 1,
);

final rolesFiltradosProvider = Provider.autoDispose<List<Rol>>((ref) {
  final todos = ref.watch(rolesProvider).valueOrNull ?? const <Rol>[];
  final texto = ref.watch(busquedaRolesProvider).trim().toLowerCase();
  final estado = ref.watch(estadoFiltroProvider);

  return todos
      .where((r) => pasaEstado(r.activo, estado))
      .where((r) => texto.isEmpty || r.buscable.contains(texto))
      .toList();
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

final filtrosEmpresasActivosProvider = Provider.autoDispose(
  (ref) => ref.watch(estadoFiltroProvider) == FiltroEstado.activos ? 0 : 1,
);

final empresasFiltradasProvider = Provider.autoDispose<List<Empresa>>((ref) {
  final todas = ref.watch(empresasProvider).valueOrNull ?? const <Empresa>[];
  final texto = ref.watch(busquedaEmpresasProvider).trim().toLowerCase();
  final estado = ref.watch(estadoFiltroProvider);

  return todas
      .where((e) => pasaEstado(e.activa, estado))
      .where((e) => texto.isEmpty || e.buscable.contains(texto))
      .toList();
});
