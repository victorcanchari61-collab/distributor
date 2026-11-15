import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/dimensiones.dart';
import '../../core/tema/colores.dart';
import 'app_pestanas.dart';

/// Hasta dónde sube una hoja: justo debajo de la barra de arriba de la
/// pantalla, que sigue a la vista para saber dónde se está. Lo usa el tema
/// (para todas las hojas) y [HojaBase].
double altoMaximoHoja(BuildContext context) {
  final pantalla = MediaQuery.sizeOf(context).height;
  // Al arrancar, en Android el primer cuadro llega con la pantalla midiendo 0:
  // restarle la barra daba -56, una altura imposible, y como esto va en el
  // tema de toda la app salía la pantalla roja. Sin medida todavía, sin tope.
  if (pantalla <= 0) return double.infinity;
  final arriba = MediaQuery.paddingOf(context).top;
  // Nunca menos de la mitad de la pantalla: en un teléfono acostado (muy bajo)
  // restar la barra dejaba la hoja demasiado chica para usarla.
  final alto = pantalla - arriba - kToolbarHeight;
  return alto < pantalla / 2 ? pantalla / 2 : alto;
}

/// La franja de color de arriba de una hoja: solo el título, en blanco, sobre el
/// color del módulo. Es la misma del modal del panel web.
class EncabezadoHoja extends StatelessWidget {
  const EncabezadoHoja(this.titulo, {super.key, this.acciones, this.subtitulo});

  final String titulo;

  /// Una línea más chica bajo el título: de quién o de qué es (el cliente de
  /// un pedido, el número de un documento).
  final String? subtitulo;

  /// Algo a la derecha del título (por ejemplo "Limpiar" en los filtros).
  final List<Widget>? acciones;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimen.espacio4,
        vertical: Dimen.espacio2,
      ),
      decoration: BoxDecoration(
        color: Acento.de(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Dimen.radioPanel),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitulo != null && subtitulo!.isNotEmpty)
                  Text(
                    subtitulo!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 11.5,
                    ),
                  ),
              ],
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
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;
  final Widget cuerpo;

  /// Los botones de abajo. Sin ellos, la hoja termina en el contenido.
  final Widget? pie;
  final List<Widget>? accionesTitulo;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: altoMaximoHoja(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoHoja(
            titulo,
            subtitulo: subtitulo,
            acciones: accionesTitulo,
          ),
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
  String? subtitulo,
}) => abrirHoja<T>(
  context,
  (_) => HojaBase(
    titulo: titulo,
    subtitulo: subtitulo,
    cuerpo: cuerpo,
    pie: pie,
    accionesTitulo: accionesTitulo,
  ),
);

/// Las pestañas de dentro de una hoja (Entrega / Recojo / Pago), con el mismo
/// diseño que las de las pantallas: en un rectángulo gris, cada una como
/// tarjetita y la activa con el color del módulo. Reemplaza al `TabBar` de
/// subrayado y sigue al mismo [TabController], así el contenido (un
/// `TabBarView`) no cambia.
class PestanasHoja extends StatelessWidget {
  const PestanasHoja({
    super.key,
    required this.controlador,
    required this.pestanas,
  });

  final TabController controlador;

  /// Una por pestaña, en el mismo orden que las vistas del controlador.
  final List<Pestana<int>> pestanas;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controlador,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(top: Dimen.espacio2),
        child: AppPestanas<int>(
          pestanas: pestanas,
          activa: controlador.index,
          onCambio: controlador.animateTo,
        ),
      ),
    );
  }
}
