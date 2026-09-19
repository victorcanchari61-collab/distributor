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
      for (var i = 0; i < n; i++)
        _grupo(i, grosorBarra, atenuada: tocado != null && tocado != i),
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
            cadaX: cadaEtiqueta(
              widget.etiquetas,
              banda,
              MediaQuery.textScalerOf(context),
            ),
          ),
          topTitles: ejeMargen(_margenSuperior),
          rightTitles: ejeMargen(derecha),
        ),
        barTouchData: BarTouchData(
          handleBuiltInTouches: false,
          // La barra que se toca no la decide fl_chart sino la posición del
          // dedo (ver `_alTocar`): así responde toda la columna, también donde
          // la barra no llega, y no solo las que tienen algo que dibujar.
          touchCallback: (evento, _) => _alTocar(evento, banda, n),
        ),
      ),
    );

    final capas = <Widget>[
      barras,
      if (linea != null) ..._capaLinea(linea, esc, n, derecha),
      if (tocado != null)
        globoSobreGrafico(
          fraccionX: (tocado + 0.5) / n,
          derecha: derecha,
          globo: _globo(tocado),
        ),
    ];
    return Stack(children: capas);
  }

  /// La línea del eje derecho, superpuesta a las barras: el gráfico, los
  /// números de su eje y nada que responda al toque.
  List<Widget> _capaLinea(
    LineaSecundaria linea,
    Escala esc,
    int n,
    double derecha,
  ) {
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

    return [
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
    ];
  }

  /// Una columna. Cuando hay otra elegida, esta se ve más tenue (como en el
  /// panel web) para que la elegida resalte sin dibujarle nada encima.
  BarChartGroupData _grupo(
    int i,
    double grosorBarra, {
    required bool atenuada,
  }) {
    Color tono(Color c) => atenuada ? c.withValues(alpha: 0.55) : c;
    final series = widget.series;
    final radio = math.min(3.0, grosorBarra / 3);

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
          tramos.add(BarChartRodStackItem(arriba, arriba + v, tono(s.color)));
          arriba += v;
        } else {
          tramos.add(BarChartRodStackItem(abajo + v, abajo, tono(s.color)));
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
      );
    } else {
      rodDe = (k) {
        final v = _valor(series[k], i);
        return BarChartRodData(
          toY: v,
          width: math.max(2.0, grosorBarra - 1.5),
          color: tono(_color(series[k], i)),
          borderRadius: v >= 0
              ? BorderRadius.vertical(top: Radius.circular(radio))
              : BorderRadius.vertical(bottom: Radius.circular(radio)),
        );
      };
    }

    return BarChartGroupData(
      x: i,
      barsSpace: 1.5,
      barRods: [
        for (var k = 0; k < (widget.apilado ? 1 : series.length); k++) rodDe(k),
      ],
    );
  }

  /// Cuál columna se tocó, por la posición del dedo.
  ///
  /// Con el acierto sobre la barra misma, un día sin movimiento (barra de alto
  /// cero) o con la barra colgando del cero no respondía nunca, y con 30 barras
  /// finas acertarles a las demás era cuestión de suerte. Todas las columnas
  /// miden lo mismo (`banda`). La posición que da fl_chart ya viene medida
  /// desde el borde izquierdo del área de las barras, sin los números del eje.
  void _alTocar(FlTouchEvent evento, double banda, int n) {
    final posicion = evento.localPosition;
    if (posicion == null) return;

    final i = (posicion.dx / banda).floor();
    final dentro = posicion.dx >= 0 && i >= 0 && i < n;

    if (dentro) {
      if (i != _tocado) setState(() => _tocado = i);
    } else if (evento is FlTapUpEvent && _tocado != null) {
      // Se tocó fuera de las columnas: se cierra el globo.
      setState(() => _tocado = null);
    }
  }

  /// El globo: el día arriba y una línea por serie.
  Widget _globo(int i) {
    final rotulos = widget.etiquetasLargas ?? widget.etiquetas;

    // Apiladas: solo lo que aportó algo, salvo que no haya nada (entonces la
    // primera, para que el globo no quede vacío). Un método de pago sin cobros
    // ese día es ruido en pantalla de teléfono.
    var series = widget.series;
    if (widget.apilado) {
      final conValor = series.where((s) => _valor(s, i) != 0).toList();
      series = conValor.isEmpty ? series.take(1).toList() : conValor;
    }

    final linea = widget.linea;
    final valorLinea = linea != null && i < linea.valores.length
        ? linea.valores[i]
        : null;

    return GloboDetalle(
      titulo: i < rotulos.length ? rotulos[i] : '',
      filas: [
        for (final s in series)
          FilaGlobo(_color(s, i), s.nombre, widget.formato(_valor(s, i))),
        if (linea != null && valorLinea != null)
          FilaGlobo(linea.color, linea.nombre, linea.formato(valorLinea)),
      ],
    );
  }
}
