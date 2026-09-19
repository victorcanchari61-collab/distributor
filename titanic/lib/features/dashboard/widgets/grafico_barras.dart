import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'grafico_ejes.dart';
import 'grafico_util.dart';

class SerieBarra {
  const SerieBarra({
    required this.id,
    required this.nombre,
    required this.color,
    required this.valores,
  });

  final String id;
  final String nombre;
  final Color color;
  final List<double> valores;
}

/// Una línea sobre las barras, con su propio eje a la derecha: el margen (%)
/// sobre la ganancia (S/).
class LineaSecundaria {
  const LineaSecundaria({
    required this.nombre,
    required this.color,
    required this.valores,
    required this.formato,
    this.max,
  });

  final String nombre;
  final Color color;
  final List<double?> valores;
  final String Function(double) formato;

  /// Tope del eje derecho; por defecto lo decide el dato.
  final double? max;
}

/// Barras verticales, sueltas o apiladas, con una línea opcional sobre un
/// segundo eje. Las barras con valor negativo cuelgan del cero: una ganancia
/// negativa se ve.
///
/// fl_chart no tiene un segundo eje: la línea es un gráfico de líneas
/// superpuesto al de barras. Los dos reservan exactamente los mismos márgenes
/// (`ejeIzquierdo`, `ejeInferior`) y sus puntos caen en el centro de cada
/// barra — la x de la línea va de -0.5 a n-0.5 —, así que sus áreas coinciden.
///
/// Al tocar una barra el globo se queda hasta que se toque otra o el hueco
/// entre dos.
class GraficoBarras extends StatefulWidget {
  const GraficoBarras({
    super.key,
    required this.etiquetas,
    required this.series,
    this.apilado = false,
    this.linea,
    this.alto = 220,
    this.formato = compacto,
    this.formatoEje = compacto,
    this.etiquetasLargas,
    this.colorDe,
  });

  final List<String> etiquetas;
  final List<SerieBarra> series;

  /// Las series se apilan en una sola barra en vez de ir una al lado de otra.
  final bool apilado;
  final LineaSecundaria? linea;
  final double alto;
  final String Function(double) formato;
  final String Function(double) formatoEje;
  final List<String>? etiquetasLargas;

  /// Colorea cada barra de una serie única según su valor y posición
  /// (semáforo).
  final Color Function(double valor, int indice)? colorDe;

  @override
  State<GraficoBarras> createState() => _GraficoBarrasState();
}

class _GraficoBarrasState extends State<GraficoBarras> {
  int? _tocado;

  static const _margenSuperior = 8.0;

  @override
  void didUpdateWidget(GraficoBarras anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.series != widget.series ||
        anterior.etiquetas != widget.etiquetas) {
      _tocado = null;
    }
  }

  double _valor(SerieBarra s, int i) => i < s.valores.length ? s.valores[i] : 0;

  Color _color(SerieBarra s, int i) {
    final decide = widget.colorDe;
    return decide != null && widget.series.length == 1
        ? decide(_valor(s, i), i)
        : s.color;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.etiquetas.length;
    if (n == 0 || widget.series.isEmpty) return SizedBox(height: widget.alto);

    return SizedBox(
      height: widget.alto,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, caja) => _grafico(caja.maxWidth, n),
      ),
    );
  }

  Widget _grafico(double ancho, int n) {
    final apilado = widget.apilado;
    final linea = widget.linea;
    final derecha = linea != null ? 40.0 : 12.0;

    // El rango del eje lo dan las barras: apiladas suman, sueltas se comparan.
    final cimas = <double>[];
    final simas = <double>[];
    for (var i = 0; i < n; i++) {
      final valores = [for (final s in widget.series) _valor(s, i)];
      if (apilado) {
        cimas.add(valores.where((v) => v > 0).fold(0.0, (a, b) => a + b));
        simas.add(valores.where((v) => v < 0).fold(0.0, (a, b) => a + b));
      } else {
        cimas.add(maximoDe(valores));
        simas.add(minimoDe(valores));
      }
    }
    final esc = escala(minimoDe(simas), maximoDe(cimas));

    final anchoUtil = math.max(10.0, ancho - ejeIzquierdo - derecha);
    final banda = anchoUtil / n;
    final grosorGrupo = math.min(48.0, banda * 0.7);
    final grosorBarra = apilado
        ? grosorGrupo
        : math.max(3.0, grosorGrupo / widget.series.length);

    final tocado = _tocado != null && _tocado! < n ? _tocado : null;

    final grupos = [
      for (var i = 0; i < n; i++) _grupo(i, esc, grosorBarra, tocado == i),
    ];

    final barras = BarChart(
      duration: Duration.zero,
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: grupos,
        minY: esc.min,
        maxY: esc.max,
        gridData: rejillaHorizontal(pasoDe(esc)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: ejeVertical(
            paso: pasoDe(esc),
            formato: widget.formatoEje,
          ),
          bottomTitles: ejeHorizontal(
            etiquetas: widget.etiquetas,
            cadaX: cadaEtiqueta(n, anchoUtil),
          ),
          topTitles: ejeMargen(_margenSuperior),
          rightTitles: ejeMargen(derecha),
        ),
        barTouchData: BarTouchData(
          handleBuiltInTouches: false,
          allowTouchBarBackDraw: true,
          // Toda la banda es del dedo, no solo el ancho de la barra: con 30
          // barras finas, acertarles era cuestión de suerte.
          touchExtraThreshold: EdgeInsets.symmetric(
            horizontal: math.max(0.0, (banda - grosorBarra) / 2),
            vertical: 4,
          ),
          touchCallback: _alTocar,
          touchTooltipData: globoBarras(_globo),
        ),
      ),
    );

    if (linea == null) return barras;

    // El eje de la línea. Si las barras bajan de cero, el de la línea también,
    // y con el cero en el MISMO renglón: dos ceros a alturas distintas hacen
    // que un margen negativo parezca positivo junto a una ganancia negativa.
    final valoresLinea = linea.valores.whereType<double>();
    final datoMax = maximoDe(valoresLinea);
    final datoMin = minimoDe(valoresLinea);
    double maxLinea;
    double minLinea;
    if (esc.min < 0 && esc.max > 0) {
      final proporcion = esc.min / esc.max;
      maxLinea = escala(
        0,
        math.max(linea.max ?? datoMax, datoMin < 0 ? datoMin / proporcion : 0),
        2,
      ).max;
      minLinea = maxLinea * proporcion;
    } else {
      maxLinea = linea.max ?? escala(0, datoMax, 4).max;
      minLinea = datoMin < 0 ? escala(datoMin, 0, 2).min : 0;
    }
    final rango = maxLinea - minLinea == 0 ? 1.0 : maxLinea - minLinea;

    final altoUtil = widget.alto - _margenSuperior - ejeInferior;
    double yDe(double v) =>
        _margenSuperior + altoUtil - (v - minLinea) / rango * altoUtil;

    final marcasEje = minLinea < 0
        ? [minLinea, 0.0, maxLinea]
        : [0.0, maxLinea / 2, maxLinea];

    return Stack(
      children: [
        barras,
        // Sin tacto: el que responde es el de las barras.
        IgnorePointer(
          child: LineChart(
            duration: Duration.zero,
            LineChartData(
              minX: -0.5,
              maxX: n - 0.5,
              minY: minLinea,
              maxY: maxLinea,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: ejeMargen(ejeIzquierdo),
                bottomTitles: ejeMargen(ejeInferior),
                topTitles: ejeMargen(_margenSuperior),
                rightTitles: ejeMargen(derecha),
              ),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < n; i++)
                      i < linea.valores.length && linea.valores[i] != null
                          ? FlSpot(i.toDouble(), linea.valores[i]!)
                          : FlSpot.nullSpot,
                  ],
                  color: linea.color,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  isStrokeJoinRound: true,
                  dotData: FlDotData(
                    // Con 60 días los puntos serían una hilera de bolitas.
                    show: n <= 31,
                    getDotPainter: (spot, porcentaje, barra, i) =>
                        FlDotCirclePainter(
                          radius: 2.8,
                          color: Colors.white,
                          strokeColor: linea.color,
                          strokeWidth: 1.8,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Los números del eje derecho, a la altura de su escala.
        for (final v in marcasEje)
          Positioned(
            right: 0,
            top: yDe(v) - 7,
            width: derecha - 4,
            child: IgnorePointer(
              child: Text(
                linea.formato(v),
                maxLines: 1,
                style: estiloEje.copyWith(color: linea.color),
              ),
            ),
          ),
      ],
    );
  }

  BarChartGroupData _grupo(int i, Escala esc, double grosorBarra, bool activo) {
    final series = widget.series;
    final radio = math.min(3.0, grosorBarra / 3);

    // Todo el alto de la banda responde al toque, también donde la barra no
    // llega (un día sin movimiento).
    final fondoTactil = BackgroundBarChartRodData(
      show: true,
      toY: esc.max,
      color: Colors.transparent,
    );

    final BarChartRodData Function(int) rodDe;
    if (widget.apilado) {
      // Positivos hacia arriba, negativos hacia abajo, cada uno acumulado por
      // su lado.
      var arriba = 0.0;
      var abajo = 0.0;
      final tramos = <BarChartRodStackItem>[];
      for (final s in series) {
        final v = _valor(s, i);
        if (v == 0) continue;
        if (v > 0) {
          tramos.add(BarChartRodStackItem(arriba, arriba + v, s.color));
          arriba += v;
        } else {
          tramos.add(BarChartRodStackItem(abajo + v, abajo, s.color));
          abajo += v;
        }
      }
      rodDe = (_) => BarChartRodData(
        fromY: abajo,
        toY: arriba,
        width: grosorBarra,
        color: Colors.transparent,
        rodStackItems: tramos,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radio)),
        backDrawRodData: fondoTactil,
      );
    } else {
      rodDe = (k) {
        final v = _valor(series[k], i);
        return BarChartRodData(
          toY: v,
          width: math.max(2.0, grosorBarra - 1.5),
          color: _color(series[k], i),
          borderRadius: v >= 0
              ? BorderRadius.vertical(top: Radius.circular(radio))
              : BorderRadius.vertical(bottom: Radius.circular(radio)),
          backDrawRodData: fondoTactil,
        );
      };
    }

    return BarChartGroupData(
      x: i,
      barsSpace: 1.5,
      barRods: [
        for (var k = 0; k < (widget.apilado ? 1 : series.length); k++) rodDe(k),
      ],
      showingTooltipIndicators: activo ? const [0] : const [],
    );
  }

  void _alTocar(FlTouchEvent evento, BarTouchResponse? respuesta) {
    final punto = respuesta?.spot;

    if (punto != null) {
      final i = punto.touchedBarGroupIndex;
      if (i != _tocado) setState(() => _tocado = i);
    } else if (evento is FlTapUpEvent && _tocado != null) {
      // Se tocó entre dos barras: se cierra el globo.
      setState(() => _tocado = null);
    }
  }

  /// El globo: el día arriba y una línea por serie.
  BarTooltipItem? _globo(
    BarChartGroupData grupo,
    int indiceGrupo,
    BarChartRodData rod,
    int indiceRod,
  ) {
    final i = grupo.x;
    final rotulos = widget.etiquetasLargas ?? widget.etiquetas;
    if (i < 0 || i >= rotulos.length) return null;

    // Apiladas: solo lo que aportó algo, salvo que no haya nada (entonces la
    // primera, para que el globo no quede vacío). Un método de pago sin cobros
    // ese día es ruido en pantalla de teléfono.
    var series = widget.series.indexed.toList();
    if (widget.apilado) {
      final conValor = series.where((e) => _valor(e.$2, i) != 0).toList();
      series = conValor.isEmpty ? series.take(1).toList() : conValor;
    }

    final linea = widget.linea;
    final valorLinea = linea != null && i < linea.valores.length
        ? linea.valores[i]
        : null;

    return BarTooltipItem(
      '',
      estiloGlobo,
      textAlign: TextAlign.left,
      children: [
        TextSpan(
          text: rotulos[i],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final (_, s) in series) ...[
          const TextSpan(text: '\n'),
          ...renglonGlobo(_color(s, i), s.nombre, widget.formato(_valor(s, i))),
        ],
        if (linea != null && valorLinea != null) ...[
          const TextSpan(text: '\n'),
          ...renglonGlobo(linea.color, linea.nombre, linea.formato(valorLinea)),
        ],
      ],
    );
  }
}
