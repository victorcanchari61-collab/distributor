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

/// Estado por el que se filtra un listado.
enum FiltroEstado { activos, inactivos, todos }

/// Filtro de estado. Por defecto solo los activos: es lo que se usa a diario.
final estadoFiltroProvider = StateProvider.autoDispose(
  (ref) => FiltroEstado.activos,
);

/// Filtros propios de clientes. Null es "todos".
final diaVisitaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final rutaFiltroProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Filtro propio de proveedores.
final rubroFiltroProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Cuantos filtros hay puestos, para el globo del icono de filtros.
final filtrosClientesActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(estadoFiltroProvider) != FiltroEstado.activos) n++;
  if (ref.watch(diaVisitaFiltroProvider) != null) n++;
  if (ref.watch(rutaFiltroProvider) != null) n++;
  return n;
});

final filtrosProveedoresActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(estadoFiltroProvider) != FiltroEstado.activos) n++;
  if (ref.watch(rubroFiltroProvider) != null) n++;
  return n;
});

/// Comprueba un registro contra el filtro de estado.
bool _pasaEstado(bool activo, FiltroEstado filtro) => switch (filtro) {
  FiltroEstado.activos => activo,
  FiltroEstado.inactivos => !activo,
  FiltroEstado.todos => true,
};

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
  final estado = ref.watch(estadoFiltroProvider);
  final dia = ref.watch(diaVisitaFiltroProvider);
  final ruta = ref.watch(rutaFiltroProvider);

  return todos
      .where((c) => _pasaEstado(c.activo, estado))
      .where((c) => dia == null || c.diaVisita == dia)
      .where((c) => ruta == null || c.ruta == ruta)
      .where((c) => texto.isEmpty || c.buscable.contains(texto))
      .toList();
});

/// Rutas que existen en los datos, para armar el filtro sin listas fijas.
final rutasProvider = Provider.autoDispose<List<String>>((ref) {
  final todos = ref.watch(clientesProvider).valueOrNull ?? const <Cliente>[];
  final rutas = todos
      .map((c) => c.ruta)
      .whereType<String>()
      .where((r) => r.trim().isNotEmpty)
      .toSet()
      .toList();
  // Numericas cuando se puede: "2" antes que "10".
  rutas.sort((a, b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.compareTo(b);
  });
  return rutas;
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
  final estado = ref.watch(estadoFiltroProvider);
  final rubro = ref.watch(rubroFiltroProvider);

  return todos
      .where((p) => _pasaEstado(p.activo, estado))
      .where((p) => rubro == null || p.rubro == rubro)
      .where((p) => texto.isEmpty || p.buscable.contains(texto))
      .toList();
});

/// Rubros que existen en los datos.
final rubrosProvider = Provider.autoDispose<List<String>>((ref) {
  final todos =
      ref.watch(proveedoresProvider).valueOrNull ?? const <Proveedor>[];
  final rubros =
      todos
          .map((p) => p.rubro)
          .whereType<String>()
          .where((r) => r.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return rubros;
});
