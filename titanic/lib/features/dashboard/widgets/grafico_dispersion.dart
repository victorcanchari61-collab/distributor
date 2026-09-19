import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';
import 'grafico_util.dart';

class PuntoDispersion {
  const PuntoDispersion({
    required this.nombre,
    required this.x,
    required this.y,
    required this.color,
    required this.detalle,
    this.rotulo = false,
  });

  final String nombre;
  final double x;
  final double y;
  final Color color;

  /// Lo que se dice del punto al tocarlo, debajo del nombre.
  final String detalle;

  /// Se escribe el nombre junto al punto (solo los más importantes, para no
  /// amontonar).
  final bool rotulo;
}

/// Las líneas que parten el plano en cuatro y el rótulo de cada esquina.
class CuadrantesDispersion {
  const CuadrantesDispersion({
    required this.x,
    required this.y,
    required this.rotulos,
  });

  final double x;
  final double y;

  /// [arriba-izquierda, arriba-derecha, abajo-izquierda, abajo-derecha]
  final List<String> rotulos;
}

/// Dispersión con cuadrantes. Sirve para ver de un vistazo qué productos venden
/// mucho y dejan poco, y cuáles dejan mucho pero se mueven poco: la respuesta a
/// "dónde pongo el esfuerzo".
///
/// Se dibuja en un lienzo y no con el `ScatterChart` de fl_chart porque este no
/// puede trazar las dos líneas que parten el plano ni rotular las esquinas, y
/// eso es justo lo que le da sentido al gráfico. Al tocar se elige el punto más
/// cercano (con margen de dedo) y su detalle sale debajo.
class GraficoDispersion extends StatefulWidget {
  const GraficoDispersion({
    super.key,
    required this.puntos,
    required this.etiquetaX,
    required this.etiquetaY,
    this.formatoX = compacto,
    this.formatoY = compacto,
    this.cuadrantes,
    this.alto = 320,
  });

  final List<PuntoDispersion> puntos;
  final String etiquetaX;
  final String etiquetaY;
  final String Function(double) formatoX;
  final String Function(double) formatoY;
  final CuadrantesDispersion? cuadrantes;
  final double alto;

  @override
  State<GraficoDispersion> createState() => _GraficoDispersionState();
}

class _GraficoDispersionState extends State<GraficoDispersion> {
  int? _elegido;

  @override
  void didUpdateWidget(GraficoDispersion anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.puntos != widget.puntos) _elegido = null;
  }

  @override
  Widget build(BuildContext context) {
    final puntos = widget.puntos;
    final ex = escala(0, maximoDe(puntos.map((p) => p.x), 1));
    final ey = escala(
      minimoDe(puntos.map((p) => p.y)),
      maximoDe(puntos.map((p) => p.y), 1),
    );

    final elegido = _elegido != null && _elegido! < puntos.length
        ? puntos[_elegido!]
        : null;

    return LayoutBuilder(
      builder: (context, caja) {
        final geometria = _Geometria(caja.maxWidth, widget.alto, ex, ey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => setState(
                () => _elegido = _masCercano(d.localPosition, geometria),
              ),
              child: CustomPaint(
                size: Size(caja.maxWidth, widget.alto),
                painter: _DispersionPainter(
                  puntos: puntos,
                  geometria: geometria,
                  etiquetaX: widget.etiquetaX,
                  etiquetaY: widget.etiquetaY,
                  formatoX: widget.formatoX,
                  formatoY: widget.formatoY,
                  cuadrantes: widget.cuadrantes,
                  elegido: _elegido,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Alto fijo: que al tocar no se mueva lo que hay debajo.
            SizedBox(
              height: 48,
              child: elegido == null
                  ? const Text(
                      'Toca un punto para ver el producto',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colores.tintaTenue,
                      ),
                    )
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${elegido.nombre}\n',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colores.tinta,
                            ),
                          ),
                          TextSpan(text: elegido.detalle),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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

  /// El punto más cercano al dedo, si hay alguno a menos de 28 px: un punto de
  /// 6 px de radio es más chico que la yema.
  int? _masCercano(Offset toque, _Geometria g) {
    int? mejor;
    var distancia = 28.0;
    for (var i = 0; i < widget.puntos.length; i++) {
      final d =
          (Offset(g.px(widget.puntos[i].x), g.py(widget.puntos[i].y)) - toque)
              .distance;
      if (d <= distancia) {
        distancia = d;
        mejor = i;
      }
    }
    return mejor;
  }
}

/// Dónde cae cada valor en el lienzo.
class _Geometria {
  _Geometria(this.ancho, this.alto, this.ex, this.ey);

  final double ancho;
  final double alto;
  final Escala ex;
  final Escala ey;

  static const izq = 48.0;
  static const der = 14.0;
  static const arriba = 12.0;
  static const abajo = 38.0;

  double get anchoUtil => math.max(10, ancho - izq - der);
  double get altoUtil => math.max(10, alto - arriba - abajo);

  double px(double v) =>
      izq +
      (v - ex.min) / (ex.max - ex.min == 0 ? 1 : ex.max - ex.min) * anchoUtil;
  double py(double v) =>
      arriba +
      altoUtil -
      (v - ey.min) / (ey.max - ey.min == 0 ? 1 : ey.max - ey.min) * altoUtil;
}

class _DispersionPainter extends CustomPainter {
  _DispersionPainter({
    required this.puntos,
    required this.geometria,
    required this.etiquetaX,
    required this.etiquetaY,
    required this.formatoX,
    required this.formatoY,
    required this.cuadrantes,
    required this.elegido,
  });

  final List<PuntoDispersion> puntos;
  final _Geometria geometria;
  final String etiquetaX;
  final String etiquetaY;
  final String Function(double) formatoX;
  final String Function(double) formatoY;
  final CuadrantesDispersion? cuadrantes;
  final int? elegido;

  static const _tinta = Color(0xFF334155);

  TextPainter _tp(String texto, TextStyle estilo) => TextPainter(
    text: TextSpan(text: texto, style: estilo),
    textDirection: TextDirection.ltr,
  )..layout();

  /// Escribe un texto anclado por su borde: [ancla] es el punto donde termina
  /// (derecha), empieza (izquierda) o está el centro.
  void _texto(
    Canvas canvas,
    String texto,
    Offset ancla,
    TextStyle estilo, {
    TextAlign alinear = TextAlign.center,
  }) {
    final tp = _tp(texto, estilo);
    final x = switch (alinear) {
      TextAlign.right || TextAlign.end => ancla.dx - tp.width,
      TextAlign.left || TextAlign.start => ancla.dx,
      _ => ancla.dx - tp.width / 2,
    };
    tp.paint(canvas, Offset(x, ancla.dy - tp.height / 2));
  }

  /// Una línea de trazos: `Canvas` no la trae.
  void _punteada(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, [
    double trazo = 4,
    double hueco = 4,
  ]) {
    final largo = (b - a).distance;
    if (largo == 0) return;
    final u = (b - a) / largo;
    for (var d = 0.0; d < largo; d += trazo + hueco) {
      canvas.drawLine(a + u * d, a + u * math.min(d + trazo, largo), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometria;
    final derecha = g.ancho - _Geometria.der;

    // Rejilla y números del eje Y. El cero, en rojo suave: por debajo hay
    // pérdida.
    for (final p in g.ey.pasos) {
      final y = g.py(p);
      final paint = Paint()
        ..strokeWidth = 1
        ..color = p == 0 ? const Color(0xFFFCA5A5) : Colores.linea;
      if (p == 0) {
        canvas.drawLine(Offset(_Geometria.izq, y), Offset(derecha, y), paint);
      } else {
        _punteada(
          canvas,
          Offset(_Geometria.izq, y),
          Offset(derecha, y),
          paint,
          3,
          4,
        );
      }
      _texto(
        canvas,
        formatoY(p),
        Offset(_Geometria.izq - 8, y),
        estiloEje,
        alinear: TextAlign.right,
      );
    }

    for (final p in g.ex.pasos) {
      _texto(canvas, formatoX(p), Offset(g.px(p), g.alto - 24), estiloEje);
    }

    const estiloTitulo = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: Colores.tintaSuave,
    );
    _texto(
      canvas,
      etiquetaX,
      Offset(_Geometria.izq + g.anchoUtil / 2, g.alto - 6),
      estiloTitulo,
    );

    canvas.save();
    canvas.translate(11, _Geometria.arriba + g.altoUtil / 2);
    canvas.rotate(-math.pi / 2);
    _texto(canvas, etiquetaY, Offset.zero, estiloTitulo);
    canvas.restore();

    final c = cuadrantes;
    if (c != null) {
      final trazo = Paint()
        ..strokeWidth = 1
        ..color = Colores.tintaTenue;
      final cx = g.px(c.x);
      final cy = g.py(c.y);
      _punteada(
        canvas,
        Offset(cx, _Geometria.arriba),
        Offset(cx, _Geometria.arriba + g.altoUtil),
        trazo,
      );
      _punteada(canvas, Offset(_Geometria.izq, cy), Offset(derecha, cy), trazo);

      const estiloRotulo = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: Colores.tintaTenue,
      );
      final r = c.rotulos.length >= 4
          ? c.rotulos.map((t) => t.toUpperCase()).toList()
          : null;
      if (r != null) {
        _texto(
          canvas,
          r[0],
          Offset(_Geometria.izq + 6, _Geometria.arriba + 8),
          estiloRotulo,
          alinear: TextAlign.left,
        );
        _texto(
          canvas,
          r[1],
          Offset(derecha - 6, _Geometria.arriba + 8),
          estiloRotulo,
          alinear: TextAlign.right,
        );
        _texto(
          canvas,
          r[2],
          Offset(_Geometria.izq + 6, _Geometria.arriba + g.altoUtil - 8),
          estiloRotulo,
          alinear: TextAlign.left,
        );
        _texto(
          canvas,
          r[3],
          Offset(derecha - 6, _Geometria.arriba + g.altoUtil - 8),
          estiloRotulo,
          alinear: TextAlign.right,
        );
      }
    }

    // El elegido al final, para que quede por encima de los que lo tapan.
    final orden = [for (var i = 0; i < puntos.length; i++) i]
      ..sort((a, b) => (a == elegido ? 1 : 0) - (b == elegido ? 1 : 0));

    for (final i in orden) {
      final p = puntos[i];
      final centro = Offset(g.px(p.x), g.py(p.y));
      canvas.drawCircle(
        centro,
        i == elegido ? 8 : 6,
        Paint()..color = p.color.withValues(alpha: 0.75),
      );
      canvas.drawCircle(
        centro,
        i == elegido ? 8 : 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == elegido ? 2 : 1.5
          ..color = i == elegido ? Colores.tinta : Colors.white,
      );

      if (p.rotulo || i == elegido) {
        // Cerca del borde derecho el rótulo se escribe hacia la izquierda: si
        // no, se corta.
        final aLaIzquierda = centro.dx > g.ancho * 0.72;
        final nombre = p.nombre.length > 18
            ? '${p.nombre.substring(0, 17)}…'
            : p.nombre;
        _texto(
          canvas,
          nombre,
          Offset(centro.dx + (aLaIzquierda ? -11 : 11), centro.dy),
          estiloEje.copyWith(color: _tinta),
          alinear: aLaIzquierda ? TextAlign.right : TextAlign.left,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DispersionPainter anterior) =>
      anterior.puntos != puntos ||
      anterior.elegido != elegido ||
      anterior.geometria.ancho != geometria.ancho ||
      anterior.cuadrantes != cuadrantes;
}
