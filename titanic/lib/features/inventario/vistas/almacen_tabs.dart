import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/almacen.dart';

/// Selector de almacén, como una pestaña: cambiarlo cambia todo el conjunto
/// de datos (otro stock, otros movimientos), no filtra una lista ya cargada.
/// `valor` null es "Todos".
class AlmacenTabs extends StatelessWidget {
  const AlmacenTabs({
    super.key,
    required this.almacenes,
    required this.valor,
    required this.onCambio,
    required this.color,
  });

  final List<Almacen> almacenes;
  final int? valor;
  final ValueChanged<int?> onCambio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (almacenes.isEmpty) return const SizedBox.shrink();

    final opciones = <(int? id, String label)>[
      (null, 'Todos'),
      for (final a in almacenes) (a.id, a.nombre),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
        itemCount: opciones.length,
        separatorBuilder: (context, i) => const SizedBox(width: Dimen.espacio2),
        itemBuilder: (context, i) {
          final (id, label) = opciones[i];
          final activo = id == valor;

          return ChoiceChip(
            label: Text(label),
            selected: activo,
            onSelected: (_) => onCambio(id),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: activo ? color : Colores.tintaSuave,
            ),
            backgroundColor: Colores.superficie,
            selectedColor: color.withValues(alpha: 0.12),
            side: BorderSide(color: activo ? color : Colores.linea),
          );
        },
      ),
    );
  }
}
