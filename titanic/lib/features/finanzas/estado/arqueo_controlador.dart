import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/arqueo.dart';
import 'finanzas_controlador.dart';

/// Rango de fechas de la lista de cuadres.
///
/// De ayer a hoy: el reparto de ayer se cuadra esta manana, asi que empezar
/// solo en hoy dejaria fuera justo lo que se va a revisar primero.
final rangoCuadresProvider = StateProvider<DateTimeRange>((ref) {
  final hoy = DateTime.now();
  final finDia = DateTime(hoy.year, hoy.month, hoy.day);
  return DateTimeRange(
    start: finDia.subtract(const Duration(days: 1)),
    end: finDia,
  );
});

final busquedaCuadresProvider = StateProvider.autoDispose((ref) => '');

/// Los cuadres del rango elegido, con los pendientes incluidos.
class CuadresControlador extends AsyncNotifier<List<CuadrePendiente>> {
  @override
  Future<List<CuadrePendiente>> build() {
    final rango = ref.watch(rangoCuadresProvider);
    return ref.watch(finanzasApiProvider).cuadres(rango.start, rango.end);
  }

  Future<void> recargar() async {
    final rango = ref.read(rangoCuadresProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(finanzasApiProvider).cuadres(rango.start, rango.end),
    );
  }

  Future<void> anular(int arqueoId) async {
    await ref.read(finanzasApiProvider).anularArqueo(arqueoId);
    await recargar();
    ref.invalidate(deudasProvider);
  }
}

final cuadresProvider =
    AsyncNotifierProvider<CuadresControlador, List<CuadrePendiente>>(
      CuadresControlador.new,
    );

final cuadresFiltradosProvider = Provider.autoDispose<List<CuadrePendiente>>((
  ref,
) {
  final todos =
      ref.watch(cuadresProvider).valueOrNull ?? const <CuadrePendiente>[];
  final texto = ref.watch(busquedaCuadresProvider).trim().toLowerCase();
  if (texto.isEmpty) return todos;
  return todos
      .where(
        (c) =>
            c.usuario.toLowerCase().contains(texto) ||
            EstadoCuadre.etiqueta(c.estado).toLowerCase().contains(texto),
      )
      .toList();
});

/// Que persona y que dia se esta cuadrando.
typedef ClaveCuadre = ({DateTime fecha, int usuarioId});

/// Los cobros uno a uno mas lo ya declarado, si existe.
final detalleCuadreProvider = FutureProvider.autoDispose
    .family<DetalleCuadre, ClaveCuadre>(
      (ref, clave) => ref
          .watch(finanzasApiProvider)
          .detalleCuadre(clave.fecha, clave.usuarioId),
    );

/// Catalogo de motivos de gasto de la ruta.
final motivosGastoProvider = FutureProvider<List<MotivoGasto>>(
  (ref) => ref.watch(finanzasApiProvider).motivosGasto(),
);

final motivosGastoActivosProvider = Provider.autoDispose<List<MotivoGasto>>(
  (ref) =>
      (ref.watch(motivosGastoProvider).valueOrNull ?? const <MotivoGasto>[])
          .where((m) => m.activo)
          .toList(),
);

/// Lo que debe cada persona por faltantes.
class DeudasControlador extends AsyncNotifier<List<DeudaUsuario>> {
  @override
  Future<List<DeudaUsuario>> build() => ref.watch(finanzasApiProvider).deudas();

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(finanzasApiProvider).deudas(),
    );
  }

  Future<void> saldar(int arqueoId) async {
    await ref.read(finanzasApiProvider).saldarFaltante(arqueoId);
    await recargar();
    ref.invalidate(cuadresProvider);
  }
}

final deudasProvider =
    AsyncNotifierProvider<DeudasControlador, List<DeudaUsuario>>(
      DeudasControlador.new,
    );

/// Registra o corrige un cuadre y refresca lo que depende de el.
Future<ArqueoCaja> registrarCuadre(
  WidgetRef ref,
  Map<String, dynamic> cuerpo,
) async {
  final arqueo = await ref.read(finanzasApiProvider).registrarArqueo(cuerpo);
  await ref.read(cuadresProvider.notifier).recargar();
  ref.invalidate(deudasProvider);
  return arqueo;
}
