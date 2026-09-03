import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
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
  required List<CampoDetalle> campos,
  List<Widget> acciones = const [],
  /// Contenido libre despues de los campos, como las tarjetas de producto de
  /// una compra: no cabe en el formato etiqueta/valor de [CampoDetalle].
  List<Widget> contenidoExtra = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimen.radioPanel),
      ),
    ),
    builder: (context) {
      // 0.9: la ficha nunca tapa del todo la pantalla, para que se vea que hay
      // una lista detras y se pueda cerrar tocando fuera.
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimen.espacio4,
                0,
                Dimen.espacio4,
                Dimen.espacio3,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Dimen.radioCampo),
                    ),
                    child: Icon(icono, size: 20, color: color),
                  ),
                  const SizedBox(width: Dimen.espacio3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colores.tinta,
                                ),
                              ),
                            ),
                            if (insignia != null) ...[
                              const SizedBox(width: Dimen.espacio2),
                              insignia,
                            ],
                          ],
                        ),
                        if (subtitulo != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colores.tintaSuave,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimen.espacio4,
                  vertical: Dimen.espacio3,
                ),
                children: [
                  for (final campo in campos) FilaDato(campo),
                  if (contenidoExtra.isNotEmpty) ...[
                    const SizedBox(height: Dimen.espacio2),
                    for (final w in contenidoExtra) ...[
                      w,
                      const SizedBox(height: Dimen.espacio2),
                    ],
                  ],
                ],
              ),
            ),
            if (acciones.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Dimen.espacio3,
                  Dimen.espacio3,
                  Dimen.espacio3,
                  Dimen.espacio4 + MediaQuery.of(context).padding.bottom,
                ),
                child: Row(
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
            ],
          ],
        ),
      );
    },
  );
}
