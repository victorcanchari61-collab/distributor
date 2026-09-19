import 'dart:math' as math;

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

/// Cada cuántos puntos se escribe una etiqueta del eje horizontal para que no
/// se pisen.
///
/// Se mide el texto de verdad, no se supone un ancho: con cinco barras de un
/// teléfono ("0–7 d", "8–15 d"…) caben todas, y con 90 días de fechas ("21 ago")
/// solo una de cada quince. [separacion] es lo que hay en píxeles entre un
/// punto (o una barra) y el siguiente.
int cadaEtiqueta(
  List<String> etiquetas,
  double separacion,
  TextScaler escalaTexto,
) {
  var mayor = 0.0;
  for (final e in etiquetas) {
    final tp = TextPainter(
      text: TextSpan(text: e, style: estiloEje),
      textDirection: TextDirection.ltr,
      textScaler: escalaTexto,
    )..layout();
    mayor = math.max(mayor, tp.width);
  }

  // Un respiro de 8 px entre una etiqueta y la siguiente.
  final paso = ((mayor + 8) / math.max(separacion, 1)).ceil();
  return math.max(1, paso);
}

// ---------------------------------------------------------------- Globo

/// Un renglón del globo: el color de la serie, su nombre y su valor.
class FilaGlobo {
  const FilaGlobo(this.color, this.nombre, this.valor);

  final Color color;
  final String nombre;
  final String valor;
}

/// El detalle de lo que se tocó: el día arriba, una fila por serie y, al pie,
/// lo que dice una marca (día atípico, cierre proyectado).
///
/// Es un widget y no el globo que dibuja fl_chart por tres razones: en las
/// barras con su línea de margen la línea es OTRO gráfico encima y taparía el
/// globo del de abajo; el punto de color es un círculo de verdad y no un
/// carácter que algunas fuentes no traen; y así el de la línea y el de las
/// barras se ven idénticos.
class GloboDetalle extends StatelessWidget {
  const GloboDetalle({
    super.key,
    required this.titulo,
    required this.filas,
    this.notas = const [],
  });

  final String titulo;
  final List<FilaGlobo> filas;
  final List<({String texto, Color color})> notas;

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
      fontSize: 11.5,
      height: 1.35,
      color: Colores.tinta,
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colores.lineaFuerte),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: estilo.copyWith(fontWeight: FontWeight.w700)),
            for (final f in filas)
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: f.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      f.nombre,
                      style: estilo.copyWith(color: Colores.tintaSuave),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    f.valor,
                    style: estilo.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            for (final n in notas)
              Text(
                n.texto,
                style: estilo.copyWith(
                  color: n.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pone el globo arriba del gráfico, en el lado contrario al punto tocado: así
/// nunca tapa lo que se acaba de tocar. [fraccionX] es dónde cayó el toque, de 0
/// (izquierda) a 1 (derecha) del área de los datos.
///
/// Va junto al gráfico dentro de un `Stack`, y sin recibir toques: el dedo sigue
/// hablando con el gráfico de abajo.
Widget globoSobreGrafico({
  required double fraccionX,
  required Widget globo,
  double derecha = 12,
}) => Positioned(
  top: 4,
  left: ejeIzquierdo,
  right: derecha,
  child: IgnorePointer(
    child: Align(
      alignment: fraccionX < 0.5 ? Alignment.topRight : Alignment.topLeft,
      child: globo,
    ),
  ),
);
