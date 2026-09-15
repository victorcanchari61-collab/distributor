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
    await ref.read(finanzasApiProvider).actualizarMetodoPago(metodo.id, {
      'nombre': metodo.nombre,
      'tipo': metodo.tipo,
      'banco': metodo.banco,
      'numeroCuenta': metodo.numeroCuenta,
      'cci': metodo.cci,
      'titular': metodo.titular,
      'activo': !metodo.activo,
    });
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

final filtrosMetodosPagoActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(estadoFiltroProvider) != FiltroEstado.activos) n++;
  if (ref.watch(tipoMetodoPagoFiltroProvider) != null) n++;
  return n;
});

final metodosPagoFiltradosProvider = Provider.autoDispose<List<MetodoPago>>((
  ref,
) {
  final todos = ref.watch(metodosPagoProvider).valueOrNull ?? const <MetodoPago>[];
  final texto = ref.watch(busquedaMetodosPagoProvider).trim().toLowerCase();
  final estado = ref.watch(estadoFiltroProvider);
  final tipo = ref.watch(tipoMetodoPagoFiltroProvider);

  return todos
      .where((m) => pasaEstado(m.activo, estado))
      .where((m) => tipo == null || m.tipo == tipo)
      .where((m) => texto.isEmpty || m.buscable.contains(texto))
      .toList();
});

/// Metodos de pago activos, para los selectores de otros modulos (Compras).
final metodosPagoActivosProvider = Provider.autoDispose<List<MetodoPago>>(
  (ref) =>
      (ref.watch(metodosPagoProvider).valueOrNull ?? const <MetodoPago>[])
          .where((m) => m.activo)
          .toList(),
);
