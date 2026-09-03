import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Tarjeta de una linea de producto dentro de una hoja de detalle: nombre,
/// codigo y presentacion arriba, y sus cantidades en columnas abajo — una o
/// dos filas, segun cuantos datos tenga el documento (una compra trae
/// recibido/pendiente, una orden no).
class LineaProductoTarjeta extends StatelessWidget {
  const LineaProductoTarjeta({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.filas,
  });

  final String titulo;
  final String subtitulo;

  /// Una fila por cada grupo de columnas: `[('Cant.', '3'), ('Costo', 'S/ 6')]`.
  final List<List<(String etiqueta, String valor)>> filas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colores.tinta),
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
          for (final fila in filas) ...[
            const SizedBox(height: Dimen.espacio2),
            Row(
              children: [
                for (final (etiqueta, valor) in fila)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          etiqueta,
                          style: const TextStyle(fontSize: 10.5, color: Colores.tintaTenue),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          valor,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colores.tinta,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
