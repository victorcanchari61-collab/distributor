import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado por el que se filtra un listado. El mismo concepto en clientes,
/// productos, almacenes o cualquier otro modulo: vive aqui para que todos lo
/// compartan en vez de repetirlo.
enum FiltroEstado { activos, inactivos, todos }

/// Filtro de estado. Por defecto solo los activos: es lo que se usa a diario.
///
/// `autoDispose`: al salir de una pantalla nadie lo observa y se reinicia, asi
/// que un modulo nunca hereda el filtro que dejo puesto otro.
final estadoFiltroProvider = StateProvider.autoDispose(
  (ref) => FiltroEstado.activos,
);

/// Comprueba un registro contra el filtro de estado.
bool pasaEstado(bool activo, FiltroEstado filtro) => switch (filtro) {
  FiltroEstado.activos => activo,
  FiltroEstado.inactivos => !activo,
  FiltroEstado.todos => true,
};
