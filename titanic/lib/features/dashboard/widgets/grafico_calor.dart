import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';
import 'grafico_util.dart';

class CeldaCalor {
  const CeldaCalor({
    required this.dia,
    required this.hora,
    required this.valor,
    required this.detalle,
  });

  /// 0 = lunes … 6 = domingo.
  final int dia;
  final int hora;
  final double valor;

  /// Lo que se dice de esa celda al tocarla.
  final String detalle;
}

const _diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

/// Mapa de calor día de la semana × hora. Muestra cuándo se vende: dónde se
/// junta el color es donde conviene tener gente y mercadería.
///
/// Se dibuja en un lienzo (168 casilleros como widgets serían demasiados) y el
/// toque se traduce a día y hora por cuentas. El detalle sale en una línea
/// debajo del mapa: un globo sobre un dedo tapa justo lo que se quiere leer.
class GraficoCalor extends StatefulWidget {
  const GraficoCalor({
    super.key,
    required this.celdas,
    this.color = const Color(0xFF2563EB),
    this.horas,
  });

  final List<CeldaCalor> celdas;

  /// Color base; la intensidad es la opacidad.
  final Color color;

  /// Primera y última hora que se dibujan; por defecto, la franja donde hay
  /// datos (mínimo de 8 a 18).
  final (int, int)? horas;

  @override
  State<GraficoCalor> createState() => _GraficoCalorState();
}

class _GraficoCalorState extends State<GraficoCalor> {
  ({int dia, int hora})? _elegida;

  static const _izq = 30.0;
  static const _abajo = 18.0;

  @override
  void didUpdateWidget(GraficoCalor anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.celdas != widget.celdas) _elegida = null;
  }

  @override
  Widget build(BuildContext context) {
    final conDatos = widget.celdas
        .where((c) => c.valor > 0)
        .map((c) => c.hora)
        .toList();
    final h0 = widget.horas?.$1 ?? conDatos.fold<int>(8, math.min);
    final h1 = widget.horas?.$2 ?? conDatos.fold<int>(18, math.max);
    final nHoras = math.max(1, h1 - h0 + 1);

    final maximo = maximoDe(widget.celdas.map((c) => c.valor), 1);
    final porClave = {for (final c in widget.celdas) (c.dia, c.hora): c};

    return LayoutBuilder(
      builder: (context, caja) {
        final anchoUtil = math.max(10.0, caja.maxWidth - _izq);
        final lado = math.min(34.0, anchoUtil / nHoras);
        final altoCelda = math.min(lado, 26.0);
        final alto = 7 * altoCelda + _abajo;

        final elegida = _elegida;
        final celda = elegida == null
            ? null
            : porClave[(elegida.dia, elegida.hora)];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final k = ((d.localPosition.dx - _izq) / lado).floor();
                final dia = (d.localPosition.dy / altoCelda).floor();
                final dentro =
                    d.localPosition.dx >= _izq &&
                    k >= 0 &&
                    k < nHoras &&
                    dia >= 0 &&
                    dia < 7;
                setState(
                  () => _elegida = dentro ? (dia: dia, hora: h0 + k) : null,
                );
              },
              child: CustomPaint(
                size: Size(caja.maxWidth, alto),
                painter: _CalorPainter(
                  porClave: porClave,
                  color: widget.color,
                  maximo: maximo,
                  h0: h0,
                  nHoras: nHoras,
                  lado: lado,
                  altoCelda: altoCelda,
                  elegida: elegida,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Alto fijo: que al tocar no se mueva lo que hay debajo.
            SizedBox(
              height: 34,
              child: elegida == null
                  ? const Text(
                      'Toca una celda para ver el detalle',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colores.tintaTenue,
                      ),
                    )
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${_diasSemana[elegida.dia]} · ${elegida.hora}:00\n',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colores.tinta,
                            ),
                          ),
                          TextSpan(text: celda?.detalle ?? 'Sin ventas'),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Colores.tintaSuave,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CalorPainter extends CustomPainter {
  _CalorPainter({
    required this.porClave,
    required this.color,
    required this.maximo,
    required this.h0,
    required this.nHoras,
    required this.lado,
    required this.altoCelda,
    required this.elegida,
  });

  final Map<(int, int), CeldaCalor> porClave;
  final Color color;
  final double maximo;
  final int h0;
  final int nHoras;
  final double lado;
  final double altoCelda;
  final ({int dia, int hora})? elegida;

  static const _izq = _GraficoCalorState._izq;

  void _texto(
    Canvas canvas,
    String texto,
    Offset ancla, {
    bool derecha = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: texto, style: estiloEje),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        derecha ? ancla.dx - tp.width : ancla.dx - tp.width / 2,
        ancla.dy - tp.height / 2,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var d = 0; d < 7; d++) {
      _texto(
        canvas,
        _diasSemana[d],
        Offset(_izq - 6, d * altoCelda + altoCelda / 2),
        derecha: true,
      );
    }

    // Una hora de cada tantas: con 24 columnas angostas las etiquetas se
    // pisarían.
    final cada = math.max(1, (28 / lado).ceil());
    for (var k = 0; k < nHoras; k++) {
      if (k % cada != 0) continue;
      _texto(
        canvas,
        '${h0 + k}h',
        Offset(_izq + k * lado + lado / 2, 7 * altoCelda + 9),
      );
    }

    for (var d = 0; d < 7; d++) {
      for (var k = 0; k < nHoras; k++) {
        final valor = porClave[(d, h0 + k)]?.valor ?? 0;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            _izq + k * lado + 1,
            d * altoCelda + 1,
            lado - 2,
            altoCelda - 2,
          ),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..color = valor > 0
                ? color.withValues(
                    alpha: 0.15 + 0.85 * (valor / maximo).clamp(0, 1),
                  )
                : PaletaDash.fondoSuave,
        );

        if (elegida != null && elegida!.dia == d && elegida!.hora == h0 + k) {
          canvas.drawRRect(
            rect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = Colores.tinta,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CalorPainter anterior) =>
      anterior.porClave != porClave ||
      anterior.elegida != elegida ||
      anterior.lado != lado ||
      anterior.color != color;
}
