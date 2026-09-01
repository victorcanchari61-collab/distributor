import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';

/// Marcador para las vistas del menu que todavia no se construyen.
class PendientePagina extends StatelessWidget {
  const PendientePagina({super.key, required this.titulo, this.modulo, this.color});

  final String titulo;
  final String? modulo;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final acento = color ?? Colores.marca;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimen.espacio6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: acento.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.construction_outlined, size: 28, color: acento),
            ),
            const SizedBox(height: Dimen.espacio4),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Dimen.espacio2),
            Text(
              '${modulo == null ? '' : 'Módulo $modulo. '}Esta pantalla todavía no está construida.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colores.tintaSuave, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
