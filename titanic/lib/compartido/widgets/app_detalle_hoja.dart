import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import 'app_hoja.dart';
import 'app_tarjeta_registro.dart';

/// Hoja de detalle de un registro.
///
/// Es el equivalente movil del modal del panel web: se toca la tarjeta y sale
/// la ficha completa, con TODOS los campos y los botones de accion abajo.
/// Sube desde el borde inferior porque ahi llega el pulgar.
Future<void> mostrarDetalle(
  BuildContext context, {
  required IconData icono,
  required Color color,
  required String titulo,
  String? subtitulo,
  Widget? insignia,

  /// El estado, que va como una fila mas al final y no pegado al titulo.
  Widget? estado,
  required List<CampoDetalle> campos,
  List<Widget> acciones = const [],

  /// Contenido libre despues de los campos, como las tarjetas de producto de
  /// una compra: no cabe en el formato etiqueta/valor de [CampoDetalle].
  List<Widget> contenidoExtra = const [],
}) {
  return abrirHoja<void>(
    context,
    (context) => HojaBase(
      titulo: titulo,
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Lo que acompaña al titulo (el tipo de documento, el modulo) va
          // debajo de la franja: en ella solo cabe el titulo.
          if (subtitulo != null || insignia != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Dimen.espacio2),
              child: Row(
                children: [
                  if (subtitulo != null)
                    Expanded(
                      child: Text(
                        subtitulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colores.tintaSuave,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  ?insignia,
                ],
              ),
            ),
          for (final campo in campos) FilaDato(campo),
          if (estado != null)
            FilaDato(CampoDetalle('Estado', null, widget: estado)),
          if (contenidoExtra.isNotEmpty) ...[
            const SizedBox(height: Dimen.espacio2),
            for (final w in contenidoExtra) ...[
              w,
              const SizedBox(height: Dimen.espacio2),
            ],
          ],
        ],
      ),
      pie: acciones.isEmpty
          ? null
          : Row(
              children: [
                for (final accion in acciones)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: accion,
                    ),
                  ),
              ],
            ),
    ),
  );
}
