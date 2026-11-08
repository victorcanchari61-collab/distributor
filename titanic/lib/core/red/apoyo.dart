import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'excepciones.dart';

/// Si el error es un 403 del API: la persona no tiene permiso para ver ese dato.
bool esSinPermisoApi(Object? e) => e is ApiExcepcion && e.codigo == 403;

/// Carga un dato de APOYO de una pantalla (un catálogo de otro módulo: rutas,
/// mercados, almacenes, métodos de pago, listas de precio...) sin que su
/// ausencia tumbe la pantalla.
///
/// Es el equivalente de `opcional` de `Frontend/src/lib/apoyo.ts`. Las pantallas
/// piden de paso catálogos que quizá el rol no puede ver: antes un solo 403
/// dejaba la pantalla diciendo "No tienes permiso para esta acción" aunque la
/// persona solo quisiera ver su lista. Con esto un 403 deja ese catálogo vacío
/// (el filtro o el selector sale sin opciones) y la pantalla sigue; cualquier
/// otro error se propaga como antes.
///
/// Solo para catálogos de apoyo: los datos propios de la pantalla (su lista,
/// su resumen) NO se envuelven, porque ahí el 403 sí es el mensaje correcto.
Future<T> opcional<T>(Future<T> carga, T vacio) async {
  try {
    return await carga;
  } on ApiExcepcion catch (e) {
    if (e.codigo == 403) return vacio;
    rethrow;
  }
}

/// Lo mismo para un catálogo de apoyo que la pantalla observa como
/// `AsyncValue` (`ref.watch(rutasProvider)`): un 403 se vuelve "sin datos".
/// Cualquier otro error, y la carga, quedan igual.
extension ApoyoAsync<T> on AsyncValue<T> {
  AsyncValue<T> opcional(T vacio) =>
      hasError && !hasValue && esSinPermisoApi(error)
      ? AsyncData<T>(vacio)
      : this;
}
