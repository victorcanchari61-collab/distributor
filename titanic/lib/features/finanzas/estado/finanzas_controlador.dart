import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/estado/filtro_estado.dart';
import '../../auth/estado/auth_controlador.dart';
import '../datos/finanzas_api.dart';
import '../datos/metodo_pago.dart';

final finanzasApiProvider = Provider(
  (ref) => FinanzasApi(ref.watch(clienteApiProvider)),
);

final busquedaMetodosPagoProvider = StateProvider.autoDispose((ref) => '');

/// Listado de metodos de pago.
class MetodosPagoControlador extends AsyncNotifier<List<MetodoPago>> {
  @override
  Future<List<MetodoPago>> build() =>
      ref.watch(finanzasApiProvider).metodosPago();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(finanzasApiProvider).metodosPago(),
    );
  }

  Future<void> guardar({int? id, required Map<String, dynamic> cuerpo}) async {
    final api = ref.read(finanzasApiProvider);
    if (id == null) {
      await api.crearMetodoPago(cuerpo);
    } else {
      await api.actualizarMetodoPago(id, cuerpo);
    }
    await recargar();
  }

  Future<void> cambiarEstado(MetodoPago metodo) async {
    await ref
        .read(finanzasApiProvider)
        .actualizarMetodoPago(metodo.id, metodo.aJson(activo: !metodo.activo));
    await recargar();
  }
}

final metodosPagoProvider =
    AsyncNotifierProvider<MetodosPagoControlador, List<MetodoPago>>(
      MetodosPagoControlador.new,
    );

/// Por donde entra o sale la plata. Null es "todos".
final tipoMetodoPagoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final cuentaMetodoPagoFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosMetodosPagoActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(estadoFiltroProvider) != FiltroEstado.activos) n++;
  if (ref.watch(tipoMetodoPagoFiltroProvider) != null) n++;
  if (ref.watch(cuentaMetodoPagoFiltroProvider) != null) n++;
  return n;
});

final metodosPagoFiltradosProvider = Provider.autoDispose<List<MetodoPago>>((
  ref,
) {
  final todos =
      ref.watch(metodosPagoProvider).valueOrNull ?? const <MetodoPago>[];
  final texto = ref.watch(busquedaMetodosPagoProvider).trim().toLowerCase();
  final estado = ref.watch(estadoFiltroProvider);
  final tipo = ref.watch(tipoMetodoPagoFiltroProvider);
  final cuenta = ref.watch(cuentaMetodoPagoFiltroProvider);

  return todos
      .where((m) => pasaEstado(m.activo, estado))
      .where((m) => tipo == null || m.tipo == tipo)
      .where((m) => cuenta == null || m.cuentaFinanciera == cuenta)
      .where((m) => texto.isEmpty || m.buscable.contains(texto))
      .toList();
});

/// Cuentas a las que apuntan los metodos, para armar el filtro sin listas fijas.
final cuentasMetodoPagoProvider = Provider.autoDispose<List<String>>((ref) {
  final todos =
      ref.watch(metodosPagoProvider).valueOrNull ?? const <MetodoPago>[];
  final valores =
      todos
          .map((m) => m.cuentaFinanciera)
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return valores;
});

/// Las cuentas a las que puede apuntar un método nuevo o editado.
final cuentasElegiblesProvider =
    FutureProvider.autoDispose<List<CuentaFinancieraOpcion>>((ref) async {
      final todas = await ref.watch(finanzasApiProvider).cuentasFinancieras();
      return todas.where((c) => c.elegible).toList();
    });

/// Los métodos activos para cobrar al convertir un pedido en venta.
///
/// Va por la ruta de "opciones" y no por el catálogo: quien entrega puede tener
/// permiso de convertir pedidos sin poder ver ni editar los métodos de pago.
final metodosPagoOpcionesProvider =
    FutureProvider.autoDispose<List<MetodoPagoOpcion>>(
      (ref) => ref.watch(finanzasApiProvider).metodosPagoOpciones(),
    );

/// Metodos de pago activos, para los selectores de otros modulos (Compras).
final metodosPagoActivosProvider = Provider.autoDispose<List<MetodoPago>>(
  (ref) => (ref.watch(metodosPagoProvider).valueOrNull ?? const <MetodoPago>[])
      .where((m) => m.activo)
      .toList(),
);
