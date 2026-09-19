import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';
import 'grafico_util.dart';

/// Medidor de media luna: un porcentaje contra una meta, con el color del
/// semáforo según en qué tramo cae. [mejorAlto] invierte el sentido cuando
/// menos es mejor.
///
/// Sin dato ([valor] null) el arco queda vacío y gris, y el centro dice "—": un
/// medidor en 0% diría que todo salió mal cuando en realidad no hubo entregas.
class GraficoMedidor extends StatelessWidget {
  const GraficoMedidor({
    super.key,
    required this.valor,
    required this.titulo,
    required this.meta,
    this.mejorAlto = true,
    this.tamano = 220,
  });

  final double? valor;
  final String titulo;

  /// Desde qué % se considera bien.
  final double meta;
  final bool mejorAlto;
  final double tamano;

  Color get _color {
    final v = valor;
    if (v == null) return const Color(0xFFCBD5E1);
    final bien = mejorAlto ? v >= meta : v <= meta;
    final regular = mejorAlto ? v >= meta * 0.8 : v <= meta * 1.25;
    return bien
        ? PaletaDash.bien
        : regular
        ? PaletaDash.alerta
        : PaletaDash.mal;
  }

  @override
  Widget build(BuildContext context) {
    final v = valor;
    final fraccion = v == null || v.isNaN ? 0.0 : (v / 100).clamp(0.0, 1.0);

    return Semantics(
      label: '$titulo: ${v == null ? 'sin datos' : porcentaje(v, 0)}',
      child: SizedBox(
        width: tamano,
        height: tamano / 2 + 34,
        child: Stack(
          children: [
            CustomPaint(
              size: Size(tamano, tamano / 2 + 8),
              painter: _MedidorPainter(fraccion: fraccion, color: _color),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    v == null ? '—' : porcentaje(v, 0),
                    style: const TextStyle(
                      fontSize: 26,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: Colores.tinta,
                    ),
                  ),
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colores.tintaSuave,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedidorPainter extends CustomPainter {
  _MedidorPainter({required this.fraccion, required this.color});

  final double fraccion;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radio = size.width / 2 - 14;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.width / 2),
      radius: radio,
    );

    Paint trazo(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = c;

    // De izquierda a derecha por arriba: arranca en las 9 y barre media vuelta.
    canvas.drawArc(rect, math.pi, math.pi, false, trazo(PaletaDash.fondoSuave));
    if (fraccion > 0) {
      canvas.drawArc(rect, math.pi, math.pi * fraccion, false, trazo(color));
    }
  }

  @override
  bool shouldRepaint(_MedidorPainter anterior) =>
      anterior.fraccion != fraccion || anterior.color != color;
}
