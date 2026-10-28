import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/dimensiones.dart';
import '../../core/tema/colores.dart';

/// La franja de color de arriba de una hoja: solo el título, en blanco, sobre el
/// color del módulo. Es la misma del modal del panel web.
class EncabezadoHoja extends StatelessWidget {
  const EncabezadoHoja(this.titulo, {super.key, this.acciones});

  final String titulo;

  /// Algo a la derecha del título (por ejemplo "Limpiar" en los filtros).
  final List<Widget>? acciones;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
      decoration: BoxDecoration(
        color: Acento.de(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Dimen.radioPanel),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...?acciones,
        ],
      ),
    );
  }
}

/// El contenido de una hoja con el aspecto de un modal del panel web: arriba la
/// franja del color del módulo con solo el título, en medio el contenido que se
/// desliza, y abajo —fijo— el pie con los botones.
///
/// Es un widget y no una función para que las hojas con estado (un formulario
/// que guarda) puedan armarlo en su propio `build` y cambiar el pie —el botón
/// cargando— sin reabrir nada.
class HojaBase extends StatelessWidget {
  const HojaBase({
    super.key,
    required this.titulo,
    required this.cuerpo,
    this.pie,
    this.accionesTitulo,
  });

  final String titulo;
  final Widget cuerpo;

  /// Los botones de abajo. Sin ellos, la hoja termina en el contenido.
  final Widget? pie;
  final List<Widget>? accionesTitulo;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoHoja(titulo, acciones: accionesTitulo),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Dimen.espacio4),
              child: cuerpo,
            ),
          ),
          if (pie != null)
            Container(
              padding: EdgeInsets.fromLTRB(
                Dimen.espacio4,
                Dimen.espacio3,
                Dimen.espacio4,
                Dimen.espacio3 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colores.linea)),
              ),
              child: pie,
            ),
        ],
      ),
    );
  }
}

/// Abre una hoja inferior con la forma de un modal: esquinas redondeadas de
/// arriba, sin la manija de arrastre (la franja de color ocupa su lugar) y con
/// el lugar del teclado.
///
/// El acento del módulo se lee ANTES de abrir y se vuelve a declarar dentro: la
/// hoja cuelga del Navigator y por herencia no lo vería.
Future<T?> abrirHoja<T>(BuildContext context, WidgetBuilder builder) {
  final acento = Acento.de(context);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colores.superficie,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimen.radioPanel),
      ),
    ),
    builder: (contexto) => Acento(
      color: acento,
      child: Padding(
        // El teclado empuja la hoja entera hacia arriba.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(contexto).bottom,
        ),
        child: Builder(builder: builder),
      ),
    ),
  );
}

/// La forma corta: una hoja con título, contenido y, si hace falta, pie.
Future<T?> mostrarHoja<T>(
  BuildContext context, {
  required String titulo,
  required Widget cuerpo,
  Widget? pie,
  List<Widget>? accionesTitulo,
}) => abrirHoja<T>(
  context,
  (_) => HojaBase(
    titulo: titulo,
    cuerpo: cuerpo,
    pie: pie,
    accionesTitulo: accionesTitulo,
  ),
);
