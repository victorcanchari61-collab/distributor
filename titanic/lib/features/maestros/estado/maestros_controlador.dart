import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/cliente.dart';
import '../datos/maestros_api.dart';
import '../datos/proveedor.dart';

final maestrosApiProvider = Provider(
  (ref) => MaestrosApi(ref.watch(clienteApiProvider)),
);

/// Texto del buscador de cada listado.
final busquedaClientesProvider = StateProvider.autoDispose((ref) => '');
final busquedaProveedoresProvider = StateProvider.autoDispose((ref) => '');

/// Muestra solo los desactivados cuando esta en true.
final verInactivosProvider = StateProvider.autoDispose((ref) => false);

/// Listado de clientes.
///
/// Se trae completo una vez y se filtra en el dispositivo: son unos dos mil
/// registros, caben de sobra en memoria y asi el buscador responde al instante
/// aunque el vendedor este sin señal.
class ClientesControlador extends AsyncNotifier<List<Cliente>> {
  @override
  Future<List<Cliente>> build() => ref.watch(maestrosApiProvider).clientes();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(maestrosApiProvider).clientes(),
    );
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(maestrosApiProvider);
    if (id == null) {
      await api.crearCliente(cuerpo);
    } else {
      await api.actualizarCliente(id, cuerpo);
    }
    await recargar();
  }

  Future<void> cambiarEstado(Cliente cliente) async {
    await ref
        .read(maestrosApiProvider)
        .cambiarEstadoCliente(cliente.id, activo: !cliente.activo);
    await recargar();
  }
}

final clientesProvider =
    AsyncNotifierProvider<ClientesControlador, List<Cliente>>(
      ClientesControlador.new,
    );

/// Clientes que quedan tras aplicar buscador y filtro de estado.
final clientesFiltradosProvider = Provider.autoDispose<List<Cliente>>((ref) {
  final todos = ref.watch(clientesProvider).valueOrNull ?? const <Cliente>[];
  final texto = ref.watch(busquedaClientesProvider).trim().toLowerCase();
  final inactivos = ref.watch(verInactivosProvider);

  return todos
      .where((c) => c.activo != inactivos)
      .where((c) => texto.isEmpty || c.buscable.contains(texto))
      .toList();
});

/// Listado de proveedores.
class ProveedoresControlador extends AsyncNotifier<List<Proveedor>> {
  @override
  Future<List<Proveedor>> build() =>
      ref.watch(maestrosApiProvider).proveedores();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(maestrosApiProvider).proveedores(),
    );
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(maestrosApiProvider);
    if (id == null) {
      await api.crearProveedor(cuerpo);
    } else {
      await api.actualizarProveedor(id, cuerpo);
    }
    await recargar();
  }

  Future<void> cambiarEstado(Proveedor proveedor) async {
    await ref
        .read(maestrosApiProvider)
        .cambiarEstadoProveedor(proveedor.id, activo: !proveedor.activo);
    await recargar();
  }
}

final proveedoresProvider =
    AsyncNotifierProvider<ProveedoresControlador, List<Proveedor>>(
      ProveedoresControlador.new,
    );

final proveedoresFiltradosProvider = Provider.autoDispose<List<Proveedor>>((
  ref,
) {
  final todos =
      ref.watch(proveedoresProvider).valueOrNull ?? const <Proveedor>[];
  final texto = ref.watch(busquedaProveedoresProvider).trim().toLowerCase();
  final inactivos = ref.watch(verInactivosProvider);

  return todos
      .where((p) => p.activo != inactivos)
      .where((p) => texto.isEmpty || p.buscable.contains(texto))
      .toList();
});
