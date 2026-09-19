import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/red/excepciones.dart';
import '../../auth/estado/auth_controlador.dart';
import '../datos/dashboard_api.dart';
import '../datos/dashboard_modelos.dart';
import 'periodo_tablero.dart';

final dashboardApiProvider = Provider(
  (ref) => DashboardApi(ref.watch(clienteApiProvider)),
);

/*
 * Todo es autoDispose a propósito: igual que en el panel web, donde el estado
 * vive en el componente, salir de un tablero olvida su período y volver a
 * entrar pide los datos de nuevo. Un dashboard con datos de la visita anterior
 * engaña: el número parece de hoy y no lo es.
 *
 * Cada tablero tiene su propio período: cambiar el rango de Ventas no mueve el
 * de Cobranza.
 */

final periodoVentasProvider = StateProvider.autoDispose<PeriodoTablero>(
  (ref) => PeriodoTablero.predeterminado(),
);
final periodoRentabilidadProvider = StateProvider.autoDispose<PeriodoTablero>(
  (ref) => PeriodoTablero.predeterminado(),
);
final periodoCobranzaProvider = StateProvider.autoDispose<PeriodoTablero>(
  (ref) => PeriodoTablero.predeterminado(),
);
final periodoRepartoProvider = StateProvider.autoDispose<PeriodoTablero>(
  (ref) => PeriodoTablero.predeterminado(),
);

/// Lo que comparten los cinco tableros: volver a pedir y esperar a que llegue,
/// para que el gesto de tirar hacia abajo sepa cuándo dejar de girar.
///
/// Se invalida el propio notifier en vez de reasignar el estado a mano: si
/// mientras tanto la persona cambió el período, la respuesta vieja no puede
/// pisar la del rango nuevo porque Riverpod ya la descartó. El fallo no se
/// relanza: queda en el estado y cada gráfico lo dice en su marco.
abstract class TableroControlador<T> extends AutoDisposeAsyncNotifier<T> {
  Future<void> recargar() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {}
  }
}

/// Ventas: cuánto, a quién, quién lo vende y cuándo.
///
/// Cambiar el período reconstruye el notifier (el `watch` de abajo) y descarta
/// solo la respuesta vieja: no hace falta cancelar nada a mano.
class VentasDashboardControlador extends TableroControlador<DashboardVentas> {
  @override
  Future<DashboardVentas> build() {
    final p = ref.watch(periodoVentasProvider);
    return ref.watch(dashboardApiProvider).ventas(p.desde, p.hasta);
  }
}

final ventasDashboardProvider =
    AsyncNotifierProvider.autoDispose<
      VentasDashboardControlador,
      DashboardVentas
    >(VentasDashboardControlador.new);

/// Rentabilidad: cuánto se gana y con qué margen.
class RentabilidadDashboardControlador
    extends TableroControlador<DashboardGanancias> {
  @override
  Future<DashboardGanancias> build() {
    final p = ref.watch(periodoRentabilidadProvider);
    return ref.watch(dashboardApiProvider).ganancias(p.desde, p.hasta);
  }
}

final rentabilidadDashboardProvider =
    AsyncNotifierProvider.autoDispose<
      RentabilidadDashboardControlador,
      DashboardGanancias
    >(RentabilidadDashboardControlador.new);

/// Cobranza: cuánto se debe, hace cuánto y cuánto se cobró.
class CobranzaDashboardControlador
    extends TableroControlador<DashboardCobranza> {
  @override
  Future<DashboardCobranza> build() {
    final p = ref.watch(periodoCobranzaProvider);
    return ref.watch(dashboardApiProvider).cobranza(p.desde, p.hasta);
  }
}

final cobranzaDashboardProvider =
    AsyncNotifierProvider.autoDispose<
      CobranzaDashboardControlador,
      DashboardCobranza
    >(CobranzaDashboardControlador.new);

/// Inventario: la foto de hoy, sin rango de fechas.
class InventarioDashboardControlador
    extends TableroControlador<DashboardInventario> {
  @override
  Future<DashboardInventario> build() =>
      ref.watch(dashboardApiProvider).inventario();
}

final inventarioDashboardProvider =
    AsyncNotifierProvider.autoDispose<
      InventarioDashboardControlador,
      DashboardInventario
    >(InventarioDashboardControlador.new);

/// Pedidos y reparto: del pedido al cobro.
class RepartoDashboardControlador extends TableroControlador<DashboardReparto> {
  @override
  Future<DashboardReparto> build() {
    final p = ref.watch(periodoRepartoProvider);
    return ref.watch(dashboardApiProvider).reparto(p.desde, p.hasta);
  }
}

final repartoDashboardProvider =
    AsyncNotifierProvider.autoDispose<
      RepartoDashboardControlador,
      DashboardReparto
    >(RepartoDashboardControlador.new);

/// Lo que un dashboard tiene para pintar en este momento: los datos, o la
/// espera, o el motivo por el que fallaron.
///
/// Es el equivalente móvil de `Bloque<T>` del panel web. Mientras recarga
/// (porque cambió el período o se pidió Actualizar) cuenta como cargando aun
/// si hay datos de antes: son de otro rango y mostrarlos engañaría.
class BloqueDatos<T> {
  const BloqueDatos({this.datos, this.cargando = false, this.error});

  final T? datos;
  final bool cargando;
  final String? error;

  /// No hay nada que esperar ni nada que falló: si `datos` es null aquí, es
  /// que todavía no llegó la primera respuesta.
  bool get listo => !cargando && error == null && datos != null;
}

BloqueDatos<T> bloqueDe<T>(AsyncValue<T> estado) {
  if (estado.isLoading) return const BloqueDatos(cargando: true);
  if (estado.hasError) {
    final e = estado.error;
    return BloqueDatos(
      error: e is ApiExcepcion ? e.texto : 'No pudimos cargar este dashboard.',
    );
  }
  return BloqueDatos(datos: estado.valueOrNull);
}
