import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import 'app_boton.dart';

/// Gravedad del aviso, igual que `ConfirmTono` en el panel web.
enum ConfirmTono { peligro, aviso, pregunta }

/// Pide confirmacion antes de una accion y responde true si se acepto.
///
/// Es el equivalente movil de `useConfirmacion` del panel web: ninguna pantalla
/// arma su propio dialogo, todas llaman aqui. Si hay que cambiar como se ve o
/// como se lee un aviso, se cambia en este archivo.
///
///   if (!await confirmarAccion(context, titulo: ..., mensaje: ...)) return;
///
/// Devuelve false tambien cuando se cierra tocando fuera o con el boton atras,
/// para que dudar nunca ejecute la accion.
Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoConfirmar = 'Aceptar',
  String textoCancelar = 'Cancelar',
  ConfirmTono tono = ConfirmTono.pregunta,
}) async {
  final (icono, color) = switch (tono) {
    ConfirmTono.peligro => (Icons.delete_outline, Colores.peligro),
    ConfirmTono.aviso => (Icons.warning_amber_rounded, Colores.advertencia),
    ConfirmTono.pregunta => (Icons.help_outline, Colores.tintaSuave),
  };

  final respuesta = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colores.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimen.radioPanel),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        Dimen.espacio5,
        Dimen.espacio5,
        Dimen.espacio5,
        0,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        Dimen.espacio5,
        Dimen.espacio3,
        Dimen.espacio5,
        Dimen.espacio4,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        Dimen.espacio4,
        0,
        Dimen.espacio4,
        Dimen.espacio4,
      ),
      title: Text(
        titulo,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colores.tinta,
        ),
      ),
      // El dialogo se mide por su contenido: sin un ancho minimo los dos
      // botones quedarian demasiado angostos para su texto.
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              child: Text(
                mensaje,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: Colores.tintaSuave,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppBoton(
                texto: textoCancelar,
                variante: BotonVariante.secundario,
                expandido: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: Dimen.espacio2),
            Expanded(
              child: AppBoton(
                texto: textoConfirmar,
                expandido: true,
                // El boton toma el color del aviso: en rojo o ambar se piensa
                // dos veces antes de tocarlo.
                color: tono == ConfirmTono.pregunta ? null : color,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return respuesta ?? false;
}
