import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';
import 'grafico_util.dart';

/*
 * Piezas de fl_chart que comparten la línea, las barras y la dispersión: cómo
 * se ven los ejes, la rejilla y el globo de detalle. Van juntas para que los
 * tres gráficos se lean como uno solo y para que el ancho de los ejes sea el
 * mismo cuando dos gráficos se apilan (las barras con su línea de margen).
 */

/// Ancho que se reserva a la izquierda para los números del eje.
const double ejeIzquierdo = 48;

/// Alto que se reserva abajo para las etiquetas del eje.
const double ejeInferior = 24;

/// Un lado sin números.
const AxisTitles ejeOculto = AxisTitles(
  sideTitles: SideTitles(showTitles: false),
);

/// Un lado sin números pero con hueco: sin él, el último punto y la última
/// etiqueta quedan pegados al borde y se cortan.
AxisTitles ejeMargen(double tamano) => AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: tamano,
    // Un salto enorme y sin extremos: no se pide ninguna etiqueta, solo el hueco.
    interval: 1e12,
    minIncluded: false,
    maxIncluded: false,
    getTitlesWidget: (valor, meta) => const SizedBox.shrink(),
  ),
);

/// El eje vertical con la escala redonda.
AxisTitles ejeVertical({
  required double paso,
  required String Function(double) formato,
  double tamano = ejeIzquierdo,
  Color color = Colores.tintaTenue,
}) => AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: tamano,
    interval: paso,
    getTitlesWidget: (valor, meta) => SideTitleWidget(
      meta: meta,
      space: 6,
      child: Text(formato(valor), style: estiloEje.copyWith(color: color)),
    ),
  ),
);

/// El eje de abajo: una etiqueta cada `cadaX` puntos y siempre la última, sin
/// que se pisen entre sí.
AxisTitles ejeHorizontal({
  required List<String> etiquetas,
  required int cadaX,
  double tamano = ejeInferior,
}) {
  final n = etiquetas.length;

  // Lo mínimo que tiene que separar a la última etiqueta de la anterior: la
  // última se dibuja siempre y, sin esto, con 31 días la del 29 quedaba encima.
  final aparte = (cadaX * 0.75).ceil();

  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: tamano,
      // Un lugar por punto: cuáles llevan etiqueta lo decide el widget de abajo.
      interval: 1,
      getTitlesWidget: (valor, meta) {
        final i = valor.round();
        if ((valor - i).abs() > 1e-6 || i < 0 || i >= n) {
          return const SizedBox.shrink();
        }

        final esUltima = i == n - 1;
        final enElPaso = i % cadaX == 0 && n - 1 - i >= aparte;
        if (!esUltima && !enElPaso) return const SizedBox.shrink();

        return SideTitleWidget(
          meta: meta,
          space: 6,
          // Las de los extremos se corren hacia adentro: centradas se saldrían
          // del gráfico.
          fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
          child: Text(etiquetas[i], style: estiloEje),
        );
      },
    ),
  );
}

/// La rejilla horizontal suave, con el cero más marcado.
FlGridData rejillaHorizontal(double paso) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: paso,
  getDrawingHorizontalLine: (valor) => valor.abs() < 1e-9
      ? const FlLine(color: Colores.lineaFuerte, strokeWidth: 1)
      : const FlLine(color: Colores.linea, strokeWidth: 1, dashArray: [3, 4]),
);

/// Cuántas etiquetas del eje horizontal se saltan para que no se pisen: caben
/// unas 56 px por etiqueta.
int cadaEtiqueta(int n, double anchoUtil) {
  final caben = (anchoUtil / 56).floor();
  final cuantas = caben < 2 ? 2 : caben;
  final paso = (n / cuantas).ceil();
  return paso < 1 ? 1 : paso;
}

// ---------------------------------------------------------------- Globo

/// Estilo base del texto dentro del globo de detalle.
const estiloGlobo = TextStyle(
  fontSize: 11.5,
  height: 1.35,
  color: Colores.tinta,
);

/// Un renglón del globo: "● Nombre  valor", con el punto del color de la serie.
List<TextSpan> renglonGlobo(Color color, String nombre, String valor) => [
  TextSpan(
    text: '● ',
    style: TextStyle(color: color),
  ),
  TextSpan(text: '$nombre  '),
  TextSpan(
    text: valor,
    style: const TextStyle(fontWeight: FontWeight.w700),
  ),
];

/// Los bordes del globo: blanco con filo, para que se lea sobre la rejilla.
const _radioGlobo = 8.0;

LineTouchTooltipData globoLinea(
  List<LineTooltipItem?> Function(List<LineBarSpot>) items,
) => LineTouchTooltipData(
  getTooltipColor: (_) => Colors.white,
  tooltipBorder: const BorderSide(color: Colores.lineaFuerte),
  tooltipBorderRadius: BorderRadius.circular(_radioGlobo),
  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  tooltipMargin: 10,
  maxContentWidth: 230,
  fitInsideHorizontally: true,
  fitInsideVertically: true,
  getTooltipItems: items,
);

BarTouchTooltipData globoBarras(
  BarTooltipItem? Function(BarChartGroupData, int, BarChartRodData, int) item,
) => BarTouchTooltipData(
  getTooltipColor: (_) => Colors.white,
  tooltipBorder: const BorderSide(color: Colores.lineaFuerte),
  tooltipBorderRadius: BorderRadius.circular(_radioGlobo),
  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  tooltipMargin: 8,
  maxContentWidth: 230,
  fitInsideHorizontally: true,
  fitInsideVertically: true,
  getTooltipItem: item,
);
