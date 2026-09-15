import 'package:flutter/widgets.dart';

import '../core/red/excepciones.dart';
import 'widgets/app_aviso.dart';

/// Espera a que un catálogo esté cargado antes de ofrecerlo para elegir.
///
/// Los selectores reciben una lista ya hecha, y hasta ahora esa lista salía de
/// `ref.read(...).valueOrNull ?? []`: si la pantalla no observaba ese catálogo,
/// la primera lectura solo DISPARA la carga y devuelve null. El buscador se
/// abría con cero elementos y decía "nada coincide", que es exactamente lo
/// contrario de lo que pasaba —todavía no había llegado nada—.
///
/// Devuelve lista vacía si la carga falla, avisando del error: sin esto la
/// excepción viaja sin dueño y la hoja se abre igual de vacía y sin explicar.
Future<List<T>> catalogoListo<T>(
  BuildContext context,
  Future<List<T>> carga, {
  required String queEs,
}) async {
  try {
    return await carga;
  } on ApiExcepcion catch (e) {
    if (context.mounted) {
      Aviso.de(context).error('No pudimos cargar $queEs. ${e.texto}');
    }
    return const [];
  }
}
