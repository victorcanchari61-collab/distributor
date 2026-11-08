import 'dart:ui' show VoidCallback;

/// Lo que se dice cuando alguien toca una acción para la que no tiene permiso.
///
/// Es el mismo texto que el panel web: ahí el botón sin permiso no desaparece,
/// se muestra deshabilitado en gris y avisa al tocarlo.
const avisoSinPermiso = 'No tienes permiso para esta acción';

/// Marca de "esta acción existe pero no tienes permiso".
///
/// Las pantallas ya pasaban `puede(...) ? accion : null` a los widgets
/// compartidos, y el null hacía desaparecer el botón. Ahora pasan
/// `permitir(puede(...), accion)`: con permiso llega la acción de siempre y sin
/// él llega esta marca, que los widgets compartidos (AppBoton, AppIconoAccion,
/// el botón de crear de las listas, el abanico de acciones) reconocen y pintan
/// en gris. Null sigue significando "no se ofrece" por cualquier OTRA razón:
/// el estado del documento, una opción que no aplica, etc.
void accionSinPermiso() {}

/// Si [accion] es la marca de falta de permiso.
bool esSinPermiso(VoidCallback? accion) => identical(accion, accionSinPermiso);

/// La acción si se tiene el permiso; si no, la marca para que se vea en gris.
VoidCallback permitir(bool tiene, VoidCallback accion) =>
    tiene ? accion : accionSinPermiso;
