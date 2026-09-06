import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/arqueo_caja.dart';
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

final metodosPagoFiltradosProvider = Provider.autoDispose<List<MetodoPago>>((
  ref,
) {
  final todos = ref.watch(metodosPagoProvider).valueOrNull ?? const <MetodoPago>[];
  final texto = ref.watch(busquedaMetodosPagoProvider).trim().toLowerCase();
  return todos.where((m) => texto.isEmpty || m.buscable.contains(texto)).toList();
});

/// Metodos de pago activos, para los selectores de otros modulos (Compras).
final metodosPagoActivosProvider = Provider.autoDispose<List<MetodoPago>>(
  (ref) =>
      (ref.watch(metodosPagoProvider).valueOrNull ?? const <MetodoPago>[])
          .where((m) => m.activo)
          .toList(),
);

/// Fecha del arqueo diario que se esta consultando o registrando.
final fechaArqueoProvider = StateProvider.autoDispose<DateTime>(
  (ref) => DateTime.now(),
);

/// Resumen de cobros y pagos en efectivo del dia elegido.
final resumenArqueoProvider = FutureProvider.autoDispose<ArqueoResumen>((ref) {
  final fecha = ref.watch(fechaArqueoProvider);
  return ref.watch(finanzasApiProvider).resumenArqueo(fecha);
});

/// Historial de arqueos ya registrados.
class HistorialArqueoControlador extends AsyncNotifier<List<ArqueoCaja>> {
  @override
  Future<List<ArqueoCaja>> build() =>
      ref.watch(finanzasApiProvider).historialArqueo();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(finanzasApiProvider).historialArqueo(),
    );
  }

  Future<void> registrar(Map<String, dynamic> cuerpo) async {
    await ref.read(finanzasApiProvider).registrarArqueo(cuerpo);
    await recargar();
    ref.invalidate(resumenArqueoProvider);
  }
}

final historialArqueoProvider =
    AsyncNotifierProvider<HistorialArqueoControlador, List<ArqueoCaja>>(
      HistorialArqueoControlador.new,
    );
