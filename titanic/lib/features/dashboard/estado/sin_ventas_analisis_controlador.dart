import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/sin_ventas_analisis_api.dart';
import '../datos/sin_ventas_analisis_modelos.dart';

final sinVentasAnalisisApiProvider = Provider(
  (ref) => SinVentasAnalisisApi(ref.watch(clienteApiProvider)),
);

/// Lo que se pide al servidor: tramo, contra qué se compara, qué se mide,
/// criterio y los filtros de sucursal, categoría y marca.
final consultaSinVentasProvider = StateProvider.autoDispose<ConsultaSinVentas>(
  (ref) => ConsultaSinVentas.inicial(),
);

/// Lo que se acota sobre lo ya traído: días sin movimiento y stock.
final localesSinVentasProvider =
    StateProvider.autoDispose<FiltrosLocalesSinVentas>(
      (ref) => const FiltrosLocalesSinVentas(),
    );

/// La tarjeta tocada: la clave de un estado, [claveEnCaida] o nulo (todos).
final estadoSinVentasProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final busquedaSinVentasAnalisisProvider = StateProvider.autoDispose(
  (ref) => '',
);

final sinVentasAnalisisProvider = FutureProvider.autoDispose<AnalisisSinVentas>(
  (ref) => ref
      .watch(sinVentasAnalisisApiProvider)
      .analisis(ref.watch(consultaSinVentasProvider)),
);

/// Lo que se ve en la lista: la tarjeta elegida, el buscador y los filtros
/// locales aplicados sobre lo que llegó.
final sinVentasAnalisisFiltradosProvider =
    Provider.autoDispose<List<ProductoAnalisis>>((ref) {
      final todos =
          ref.watch(sinVentasAnalisisProvider).valueOrNull?.items ??
          const <ProductoAnalisis>[];
      return filtrarProductos(
        todos,
        estado: ref.watch(estadoSinVentasProvider),
        busqueda: ref.watch(busquedaSinVentasAnalisisProvider),
        locales: ref.watch(localesSinVentasProvider),
      );
    });

/// Un catálogo de filtro. Si el rol no tiene permiso (403) o falla, el filtro
/// se queda sin opciones: la pantalla no se cae por eso.
Future<List<OpcionCatalogo>> _opcional(
  Future<List<OpcionCatalogo>> Function() pedir,
) async {
  try {
    return await pedir();
  } catch (_) {
    return const [];
  }
}

final almacenesSinVentasProvider =
    FutureProvider.autoDispose<List<OpcionCatalogo>>(
      (ref) =>
          _opcional(() => ref.watch(sinVentasAnalisisApiProvider).almacenes()),
    );

final categoriasSinVentasProvider =
    FutureProvider.autoDispose<List<OpcionCatalogo>>(
      (ref) =>
          _opcional(() => ref.watch(sinVentasAnalisisApiProvider).categorias()),
    );

final marcasSinVentasProvider =
    FutureProvider.autoDispose<List<OpcionCatalogo>>(
      (ref) =>
          _opcional(() => ref.watch(sinVentasAnalisisApiProvider).marcas()),
    );
