import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';
import 'grafico_ejes.dart';
import 'grafico_util.dart';

/// Una línea del gráfico.
class SerieLinea {
  const SerieLinea({
    required this.id,
    required this.nombre,
    required this.color,
    required this.valores,
    this.area = false,
    this.punteada = false,
    this.grosor = 2,
  });

  final String id;
  final String nombre;
  final Color color;

  /// Un valor por etiqueta; null deja un hueco (la proyección no existe antes
  /// de hoy).
  final List<double?> valores;

  /// Rellena el área bajo la línea.
  final bool area;
  final bool punteada;
  final double grosor;
}

/// Un punto que merece atención: un día atípico, el cierre proyectado.
class MarcaLinea {
  const MarcaLinea({
    required this.indice,
    required this.serie,
    required this.color,
    required this.titulo,
  });

  final int indice;

  /// El `id` de la serie sobre la que va la marca.
  final String serie;
  final Color color;
  final String titulo;
}

/// Líneas y áreas con eje "redondo", rejilla suave y un globo de detalle al
/// tocar.
///
/// El globo se queda donde se tocó hasta que se toque otro punto o el hueco
/// entre dos: el de fl_chart por defecto desaparece al levantar el dedo, y en un
/// teléfono un toque rápido apenas lo dejaba ver.
class GraficoLinea extends StatefulWidget {
  const GraficoLinea({
    super.key,
    required this.etiquetas,
    required this.series,
    this.alto = 220,
    this.formato = compacto,
    this.formatoEje = compacto,
    this.marcas = const [],
    this.etiquetasLargas,
  });

  final List<String> etiquetas;
  final List<SerieLinea> series;
  final double alto;

  /// Cómo se escribe un valor en el globo.
  final String Function(double) formato;

  /// Cómo se escribe en el eje; por defecto, compacto.
  final String Function(double) formatoEje;
  final List<MarcaLinea> marcas;

  /// Etiquetas de otro formato para el globo ("lun 5 set") cuando las del eje
  /// son cortas.
  final List<String>? etiquetasLargas;

  @override
  State<GraficoLinea> createState() => _GraficoLineaState();
}

class _GraficoLineaState extends State<GraficoLinea> {
  /// El punto que se tocó, por posición dentro de la serie.
  int? _tocado;

  /// Espacio a la derecha para que el último punto no quede pegado al borde.
  static const _margenDerecho = 12.0;

  @override
  void didUpdateWidget(GraficoLinea anterior) {
    super.didUpdateWidget(anterior);
    // Otro período, otros datos: la selección de antes ya no apunta a nada.
    if (anterior.series != widget.series ||
        anterior.etiquetas != widget.etiquetas) {
      _tocado = null;
    }
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
    final todos = widget.series.expand((s) => s.valores).whereType<double>();
    final esc = escala(minimoDe(todos), maximoDe(todos));
    final anchoUtil = math.max(10.0, ancho - ejeIzquierdo - _margenDerecho);
    // La distancia entre dos puntos decide a partir de cuánto un toque ya no
    // es de ese punto: con media separación, cada serie solo responde en su
    // propio día y una serie con huecos no arrastra el punto de otro día.
    final separacion = n <= 1 ? anchoUtil : anchoUtil / (n - 1);
    final cadaX = cadaEtiqueta(
      widget.etiquetas,
      separacion,
      MediaQuery.textScalerOf(context),
    );

    final tocado = _tocado != null && _tocado! < n ? _tocado : null;
    final barras = [for (final s in widget.series) _barra(s, n, esc, tocado)];

    final grafico = LineChart(
      duration: Duration.zero,
      LineChartData(
        lineBarsData: barras,
        // Con un solo punto se centra: con 0..0 el gráfico no tiene ancho.
        minX: n == 1 ? -1 : 0,
        maxX: n == 1 ? 1 : (n - 1).toDouble(),
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
            cadaX: cadaX,
          ),
          topTitles: ejeMargen(8),
          rightTitles: ejeMargen(_margenDerecho),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          touchSpotThreshold: separacion / 2 + 1,
          touchCallback: _alTocar,
          getTouchedSpotIndicator: (barra, indices) => [
            for (final _ in indices)
              TouchedSpotIndicatorData(
                const FlLine(
                  color: Colores.tintaTenue,
                  strokeWidth: 1,
                  dashArray: [3, 3],
                ),
                FlDotData(
                  getDotPainter: (spot, porcentaje, b, i) => FlDotCirclePainter(
                    radius: 4.5,
                    color: Colors.white,
                    strokeColor: barra.color ?? Colores.marca,
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (tocado == null) return grafico;

    return Stack(
      children: [
        grafico,
        globoSobreGrafico(
          fraccionX: n <= 1 ? 0.5 : tocado / (n - 1),
          derecha: _margenDerecho,
          globo: _globo(tocado),
        ),
      ],
    );
  }

  LineChartBarData _barra(SerieLinea s, int n, Escala esc, int? tocado) {
    final marcas = widget.marcas.where((m) => m.serie == s.id).toList();
    final spots = <FlSpot>[
      for (var i = 0; i < n; i++)
        i < s.valores.length && s.valores[i] != null
            ? FlSpot(i.toDouble(), s.valores[i]!)
            : FlSpot.nullSpot,
    ];

    MarcaLinea? marcaEn(FlSpot spot) {
      for (final m in marcas) {
        if (m.indice == spot.x.round()) return m;
      }
      return null;
    }

    return LineChartBarData(
      spots: spots,
      color: s.color,
      barWidth: s.grosor,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dashArray: s.punteada ? const [5, 4] : null,
      // Los puntos solo se dibujan donde hay una marca (o cuando hay uno solo,
      // que sin punto no se vería nada).
      dotData: FlDotData(
        show: n == 1 || marcas.isNotEmpty,
        checkToShowDot: (spot, barra) => n == 1 || marcaEn(spot) != null,
        getDotPainter: (spot, porcentaje, barra, i) => FlDotCirclePainter(
          radius: 4,
          color: Colors.white,
          strokeColor: marcaEn(spot)?.color ?? s.color,
          strokeWidth: 2.2,
        ),
      ),
      // El área llega hasta el cero, no hasta el fondo del gráfico.
      belowBarData: BarAreaData(
        show: s.area,
        applyCutOffY: true,
        cutOffY: math.max(0, esc.min),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            s.color.withValues(alpha: 0.28),
            s.color.withValues(alpha: 0.02),
          ],
        ),
      ),
      showingIndicators: tocado != null && !spots[tocado].isNull()
          ? [tocado]
          : const [],
    );
  }

  void _alTocar(FlTouchEvent evento, LineTouchResponse? respuesta) {
    final puntos = respuesta?.lineBarSpots;

    if (puntos != null && puntos.isNotEmpty) {
      final i = puntos.first.x.round();
      if (i != _tocado) setState(() => _tocado = i);
    } else if (evento is FlTapUpEvent && _tocado != null) {
      // Se tocó el gráfico pero no un punto: se cierra el globo.
      setState(() => _tocado = null);
    }
  }

  /// El globo: el día arriba y una línea por serie que tenga valor ese día.
  Widget _globo(int i) {
    final rotulos = widget.etiquetasLargas ?? widget.etiquetas;

    return GloboDetalle(
      titulo: i < rotulos.length ? rotulos[i] : '',
      filas: [
        for (final s in widget.series)
          if (i < s.valores.length && s.valores[i] != null)
            FilaGlobo(s.color, s.nombre, widget.formato(s.valores[i]!)),
      ],
      // Lo que dice la marca (día atípico, cierre proyectado) va al pie.
      notas: [
        for (final m in widget.marcas)
          if (m.indice == i) (texto: m.titulo, color: m.color),
      ],
    );
  }
}
