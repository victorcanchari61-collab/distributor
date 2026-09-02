import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';

enum LogoVariante {
  /// Sello circular con la espiga.
  emblema,

  /// Caja con la T.
  marca,
}

/// Identidad de Titanic D, dibujada en codigo.
///
/// Se dibuja en vez de usar una imagen para que se vea nitida en cualquier
/// densidad de pantalla y pese lo mismo en todas.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.variante = LogoVariante.emblema,
    this.tam = 96,
    this.conTexto = false,
  });

  final LogoVariante variante;
  final double tam;
  final bool conTexto;

  @override
  Widget build(BuildContext context) {
    final grafico = variante == LogoVariante.emblema
        ? CustomPaint(size: Size.square(tam), painter: _EmblemaPainter())
        : _CajaT(tam: tam);

    if (!conTexto) return grafico;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        grafico,
        const SizedBox(height: 10),
        const Text(
          'TITANIC D',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            color: Colores.navy,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'DISTRIBUIDORA DE ABARROTES',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.4,
            color: Colores.bronce,
          ),
        ),
      ],
    );
  }
}

class _CajaT extends StatelessWidget {
  const _CajaT({required this.tam});

  final double tam;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tam * 0.78,
      height: tam,
      decoration: BoxDecoration(
        color: Colores.navy,
        borderRadius: BorderRadius.circular(tam * 0.22),
      ),
      alignment: Alignment.center,
      child: Text(
        'T',
        style: TextStyle(
          fontSize: tam * 0.62,
          height: 1,
          fontWeight: FontWeight.w500,
          color: Colores.dorado,
        ),
      ),
    );
  }
}

/// Sello circular: disco navy, anillo bronce y la espiga dorada.
class _EmblemaPainter extends CustomPainter {
  @override
  void paint(Canvas lienzo, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = size.width / 2;
    final escala = size.width / 120;

    lienzo.drawCircle(
      centro,
      radio,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colores.navy, Colores.navyProfundo],
        ).createShader(Rect.fromCircle(center: centro, radius: radio)),
    );

    lienzo.drawCircle(
      centro,
      radio * 0.84,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * escala
        ..color = Colores.bronce,
    );

    final grano = Paint()..color = Colores.dorado;

    void dibujarGrano(double x, double y, double giro) {
      lienzo.save();
      lienzo.translate(x * escala, y * escala);
      lienzo.rotate(giro);
      lienzo.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 12 * escala,
          height: 18 * escala,
        ),
        grano,
      );
      lienzo.restore();
    }

    dibujarGrano(60, 30.5, 0);
    for (final y in [43.0, 54.0, 65.0]) {
      dibujarGrano(49.5, y, -0.45);
      dibujarGrano(70.5, y, 0.45);
    }

    final tallo = Paint()
      ..color = Colores.dorado
      ..strokeWidth = 2.4 * escala
      ..strokeCap = StrokeCap.round;

    lienzo.drawLine(
      Offset(60 * escala, 36 * escala),
      Offset(60 * escala, 82 * escala),
      tallo,
    );

    lienzo.drawCircle(
      Offset(60 * escala, 88 * escala),
      7.5 * escala,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * escala
        ..color = Colores.dorado,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
