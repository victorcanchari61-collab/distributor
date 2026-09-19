import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';
import 'grafico_util.dart';

class ItemBarraH {
  const ItemBarraH({
    required this.nombre,
    required this.valor,
    this.color,
    this.detalle,
  });

  final String nombre;
  final double valor;

  /// Color de esta barra; si no, el de la paleta.
  final Color? color;

  /// Un segundo dato pequeño a la derecha: "3 notas", "hace 42 días".
  final String? detalle;
}

/// Barras horizontales: el nombre a la izquierda con puntos suspensivos si no
/// cabe, la barra en el medio y el valor a la derecha.
///
/// Son widgets y no un gráfico dibujado: los nombres de producto son largos y
/// el texto de un lienzo no se recorta ni se ajusta solo. Van en una `Table`
/// para que todas las barras arranquen y terminen en el mismo sitio aunque un
/// valor sea "S/ 9" y otro "S/ 12,345".
///
/// Tocar una fila muestra el nombre completo y su valor: en el teléfono no hay
/// pasar el cursor por encima, y el nombre que quedó cortado no se puede leer
/// de otro modo.
class GraficoBarrasH extends StatelessWidget {
  const GraficoBarrasH({
    super.key,
    required this.items,
    this.formato = compacto,
    this.maximo,
    this.referencias = const [],
    this.unColor,
  });

  final List<ItemBarraH> items;
  final String Function(double) formato;

  /// Fija el 100% de la barra; sin esto, lo da el mayor valor.
  final double? maximo;

  /// Marcas verticales de referencia sobre las barras (7 y 15 días de
  /// cobertura).
  final List<({double valor, String etiqueta})> referencias;

  /// Todas las barras del mismo color, en vez de recorrer la paleta.
  final Color? unColor;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Con todo en cero o negativo, el tope es 1 para no dividir entre cero.
    final tope = maximo ?? maximoDe(items.map((i) => i.valor), 1);

    return Table(
      columnWidths: const {
        0: FractionColumnWidth(0.34),
        1: FlexColumnWidth(),
        2: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (var i = 0; i < items.length; i++) _fila(items[i], i, tope),
      ],
    );
  }

  TableRow _fila(ItemBarraH item, int i, double tope) {
    final color = item.color ?? unColor ?? PaletaDash.deSerie(i);
    final fraccion = item.valor > 0
        ? (item.valor / tope).clamp(0.015, 1.0)
        : 0.0;
    final mensaje =
        '${item.nombre}\n${formato(item.valor)}'
        '${item.detalle != null ? ' · ${item.detalle}' : ''}';

    Widget conGlobo(Widget hijo) => Tooltip(
      message: mensaje,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: hijo,
    );

    return TableRow(
      children: [
        conGlobo(
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 5, 10, 5),
            child: Text(
              item.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          ),
        ),
        conGlobo(
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 5, 10, 5),
            child: SizedBox(
              height: 20,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: PaletaDash.fondoSuave,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fraccion,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  for (final r in referencias)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment(
                          -1 + 2 * (r.valor / tope).clamp(0.0, 1.0),
                          0,
                        ),
                        child: Container(
                          width: 1,
                          height: 26,
                          color: const Color(0xB394A3B8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text.rich(
            textAlign: TextAlign.right,
            TextSpan(
              children: [
                TextSpan(
                  text: formato(item.valor),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    // Una pérdida se lee en rojo, no solo por el signo.
                    color: item.valor < 0 ? PaletaDash.mal : Colores.tinta,
                  ),
                ),
                if (item.detalle != null)
                  TextSpan(
                    text: '  ${item.detalle}',
                    style: const TextStyle(color: Colores.tintaTenue),
                  ),
              ],
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
