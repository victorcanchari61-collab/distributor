import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

enum AlertaTono { error, exito, aviso }

/// Mensaje en linea dentro de un formulario o pantalla.
class AppAlerta extends StatelessWidget {
  const AppAlerta(this.mensaje, {super.key, this.tono = AlertaTono.error});

  final String mensaje;
  final AlertaTono tono;

  @override
  Widget build(BuildContext context) {
    final (fondo, borde, color, icono) = switch (tono) {
      AlertaTono.error => (
        Colores.peligroSuave,
        Colores.peligro,
        Colores.peligro,
        Icons.error_outline,
      ),
      AlertaTono.exito => (
        Colores.exitoSuave,
        Colores.exito,
        Colores.exito,
        Icons.check_circle_outline,
      ),
      AlertaTono.aviso => (
        const Color(0xFFFFFBEB),
        Colores.advertencia,
        Colores.advertencia,
        Icons.info_outline,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: fondo,
        border: Border.all(color: borde),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: Dimen.espacio2),
          Expanded(
            child: Text(mensaje, style: TextStyle(fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }
}
