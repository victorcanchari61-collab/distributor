import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Mensaje cuando un listado no tiene nada que mostrar.
class AppVacio extends StatelessWidget {
  const AppVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.detalle,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? detalle;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimen.espacio6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: Colores.lineaFuerte),
            const SizedBox(height: Dimen.espacio3),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            if (detalle != null) ...[
              const SizedBox(height: Dimen.espacio2),
              Text(
                detalle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colores.tintaSuave, height: 1.4),
              ),
            ],
            if (accion != null) ...[const SizedBox(height: Dimen.espacio4), accion!],
          ],
        ),
      ),
    );
  }
}
