import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';

enum EtiquetaTono { neutral, modulo, exito, aviso, peligro }

/// Etiqueta corta: tipo de documento, estado, dia de visita.
class AppEtiqueta extends StatelessWidget {
  const AppEtiqueta(this.texto, {super.key, this.tono = EtiquetaTono.neutral, this.color});

  final String texto;
  final EtiquetaTono tono;

  /// Color propio, para el acento del modulo.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = switch (tono) {
      EtiquetaTono.neutral => Colores.tintaSuave,
      EtiquetaTono.modulo => color ?? Colores.marca,
      EtiquetaTono.exito => Colores.exito,
      EtiquetaTono.aviso => Colores.advertencia,
      EtiquetaTono.peligro => Colores.peligro,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: base),
      ),
    );
  }
}
