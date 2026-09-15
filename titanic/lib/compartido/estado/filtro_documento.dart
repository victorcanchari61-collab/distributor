import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado por el que se filtra un listado de documentos.
///
/// No es el mismo concepto que [FiltroEstado]: un catálogo se activa y se
/// desactiva, un documento se anula. Un documento anulado no se puede volver a
/// poner vigente, y por eso el filtro por defecto muestra TODO —el anulado es
/// parte del historial y esconderlo haría cuadrar mal los números con quien
/// mira el mismo listado en la web—.
enum FiltroDocumento { todos, vigentes, anulados }

/// `autoDispose`: al salir de la pantalla nadie lo observa y se reinicia, así
/// que un listado nunca hereda el filtro que dejó puesto otro.
final filtroDocumentoProvider = StateProvider.autoDispose(
  (ref) => FiltroDocumento.todos,
);

/// Comprueba un documento contra el filtro.
bool pasaDocumento(bool anulado, FiltroDocumento filtro) => switch (filtro) {
  FiltroDocumento.todos => true,
  FiltroDocumento.vigentes => !anulado,
  FiltroDocumento.anulados => anulado,
};
