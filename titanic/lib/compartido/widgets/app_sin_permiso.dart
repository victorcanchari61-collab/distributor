import 'package:flutter/material.dart';

import '../../core/permisos/sin_permiso.dart';
import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import 'app_aviso.dart';
import 'app_tarjeta_registro.dart' show AccionesDeTarjeta;

/// Avisa que la acción tocada no está permitida.
void avisarSinPermiso(BuildContext context) =>
    Aviso.de(context).error(avisoSinPermiso);

/// Icono de acción de una fila o tarjeta (editar, anular, eliminar...).
///
/// Si [onPressed] es la marca de [permitir] sin permiso, el icono se ve
/// deshabilitado en gris, su ayuda dice "No tienes permiso para esta acción" y
/// al tocarlo lo avisa. Con null no se dibuja nada: la acción no aplica.
class AppIconoAccion extends StatelessWidget {
  const AppIconoAccion({
    super.key,
    required this.icono,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.tam = 18,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double tam;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) return const SizedBox.shrink();

    final sinPermiso = esSinPermiso(onPressed);

    // En la fila de acciones de una tarjeta: botón de color con su base más
    // oscura debajo, igual que las píldoras del panel web. Sin permiso, en gris.
    if (AccionesDeTarjeta.dentro(context)) {
      final fondo = sinPermiso
          ? const Color(0xFFE2E8F0)
          : (color ?? Acento.de(context));
      final base = Color.lerp(fondo, Colors.black, 0.28)!;
      return Tooltip(
        message: sinPermiso ? avisoSinPermiso : tooltip,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: sinPermiso
                ? null
                : [BoxShadow(color: base, offset: const Offset(0, 2.5))],
          ),
          child: Material(
            color: fondo,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: sinPermiso ? () => avisarSinPermiso(context) : onPressed,
              child: SizedBox(
                width: 38,
                height: 30,
                child: Icon(
                  icono,
                  size: tam - 1,
                  color: sinPermiso ? Colores.tintaTenue : Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: sinPermiso ? () => avisarSinPermiso(context) : onPressed,
      tooltip: sinPermiso ? avisoSinPermiso : tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icono,
        size: tam,
        color: sinPermiso ? Colores.tintaTenue : color,
      ),
    );
  }
}

/// La acción de un botón dentro de una hoja de detalle: cierra la hoja y luego
/// ejecuta.
///
/// Si la acción es la marca de falta de permiso (o null) se devuelve tal cual:
/// el botón queda en gris, avisa al tocarlo y la hoja SE QUEDA abierta, porque
/// no hay nada que hacer fuera de ella.
VoidCallback? cerrandoHoja(BuildContext context, VoidCallback? accion) {
  if (accion == null || esSinPermiso(accion)) return accion;
  return () {
    Navigator.of(context).pop();
    accion();
  };
}

/// El valor de un [PopupMenuItem] que está a la vista pero sin permiso.
const _valorSinPermiso = '__sin_permiso__';

/// Si lo elegido en un menú ⋮ es una opción sin permiso (hay que avisar y no
/// hacer nada más).
bool esValorSinPermiso(String? valor) => valor == _valorSinPermiso;

/// Una opción de un menú ⋮. Sin [permitido] se ve en gris y, al elegirla,
/// `onSelected` recibe la marca que reconoce [esValorSinPermiso].
PopupMenuItem<String> itemMenu(
  String valor,
  String texto, {
  bool permitido = true,
}) => PopupMenuItem<String>(
  value: permitido ? valor : _valorSinPermiso,
  child: Text(
    texto,
    style: permitido ? null : const TextStyle(color: Colores.tintaTenue),
  ),
);
