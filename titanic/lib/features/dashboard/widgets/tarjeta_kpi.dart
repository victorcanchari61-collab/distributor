import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import 'grafico_util.dart';
import 'marco_grafico.dart';

/// Un indicador con su tendencia: el número, cuánto cambió frente al período
/// anterior y la forma de la serie.
///
/// Mejor en verde, peor en rojo — y "mejor" lo decide quien lo usa
/// ([bajarEsBueno]), porque más deuda es peor y más ventas es mejor.
class TarjetaKpi extends StatelessWidget {
  const TarjetaKpi({
    super.key,
    required this.titulo,
    required this.valor,
    this.cambio,
    this.bajarEsBueno = false,
    this.serie,
    this.color,
    this.nota,
    this.icono,
  });

  final String titulo;
  final String valor;

  /// Variación en %, o null si no hay con qué comparar.
  final double? cambio;
  final bool bajarEsBueno;

  /// La forma del período, para el sparkline. Menos de dos puntos no dibuja.
  final List<double>? serie;
  final Color? color;
  final String? nota;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final c = cambio;
    final sube = (c ?? 0) > 0.05;
    final baja = (c ?? 0) < -0.05;
    final bueno = bajarEsBueno ? baja : sube;
    final malo = bajarEsBueno ? sube : baja;

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Igual que el valor: "Clientes que compraron" no cabe en media
              // tarjeta y "Clientes que compr…" no se entiende. Se achica.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    titulo,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colores.tintaSuave,
                    ),
                  ),
                ),
              ),
              if (icono != null) ...[
                const SizedBox(width: Dimen.espacio2),
                Icon(icono, size: 15, color: Colores.tintaTenue),
              ],
            ],
          ),
          const SizedBox(height: Dimen.espacio2),

          // En una tarjeta de medio ancho "S/ 123,456" no cabe a tamaño normal:
          // se achica en vez de cortarse, porque un número truncado es un
          // número equivocado.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 22,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: Colores.tinta,
              ),
            ),
          ),

          if (c != null) ...[
            const SizedBox(height: Dimen.espacio2),
            _ChipCambio(
              cambio: c,
              sube: sube,
              baja: baja,
              bueno: bueno,
              malo: malo,
            ),
          ],

          if (serie != null) ...[
            const SizedBox(height: Dimen.espacio2),
            Sparkline(valores: serie!, color: color ?? PaletaDash.serie.first),
          ],

          if (nota != null) ...[
            const SizedBox(height: Dimen.espacio2),
            Text(
              nota!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                color: Colores.tintaTenue,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipCambio extends StatelessWidget {
  const _ChipCambio({
    required this.cambio,
    required this.sube,
    required this.baja,
    required this.bueno,
    required this.malo,
  });

  final double cambio;
  final bool sube;
  final bool baja;
  final bool bueno;
  final bool malo;

  @override
  Widget build(BuildContext context) {
    final (fondo, texto) = bueno
        ? (const Color(0xFFECFDF5), const Color(0xFF047857))
        : malo
        ? (Colores.peligroSuave, const Color(0xFFB91C1C))
        : (PaletaDash.fondoSuave, const Color(0xFF475569));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sube
                ? Icons.north_east
                : baja
                ? Icons.south_east
                : Icons.remove,
            size: 12,
            color: texto,
          ),
          const SizedBox(width: 2),
          Text(
            '${numeroEs(cambio.abs())}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: texto,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una línea mínima sin ejes, para acompañar un número.
///
/// Con menos de dos puntos no hay forma que mostrar, pero se reserva el alto
/// para que las tarjetas de una misma fila queden parejas.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.valores,
    this.color = const Color(0xFF2563EB),
    this.alto = 34,
  });

  final List<double> valores;
  final Color color;
  final double alto;

  @override
  Widget build(BuildContext context) {
    if (valores.length < 2) return SizedBox(height: alto);

    return SizedBox(
      height: alto,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(valores, color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.valores, this.color);

  final List<double> valores;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maximo = maximoDe(valores, valores.first);
    final minimo = minimoDe(valores, valores.first);
    // Una serie plana (todo igual) no tiene rango: se dibuja al piso en vez de
    // dividir entre cero.
    final rango = maximo - minimo == 0 ? 1.0 : maximo - minimo;

    final puntos = <Offset>[
      for (var i = 0; i < valores.length; i++)
        Offset(
          i / (valores.length - 1) * size.width,
          size.height - 3 - (valores[i] - minimo) / rango * (size.height - 6),
        ),
    ];

    final linea = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (final p in puntos.skip(1)) {
      linea.lineTo(p.dx, p.dy);
    }

    final area = Path.from(linea)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
      linea,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter anterior) =>
      anterior.valores != valores || anterior.color != color;
}

/// La fila de indicadores de arriba: de a dos por renglón, con su esqueleto
/// mientras carga.
///
/// Dos columnas y no una fila que se desliza: en el tablero lo que importa es
/// ver los cuatro números de un vistazo, sin tener que arrastrar de lado.
class FilaKpi extends StatelessWidget {
  const FilaKpi({super.key, required this.cargando, required this.tarjetas});

  final bool cargando;
  final List<Widget> tarjetas;

  @override
  Widget build(BuildContext context) {
    final items = cargando
        ? List<Widget>.generate(
            4,
            (_) => const Esqueleto(alto: 132, radio: Dimen.radioPanel),
          )
        : tarjetas;

    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 2 < items.length ? Dimen.espacio3 : 0,
            ),
            // Alto parejo dentro del renglón: una con sparkline y otra con nota
            // quedaban de alturas distintas.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: items[i]),
                  if (i + 1 < items.length) ...[
                    const SizedBox(width: Dimen.espacio3),
                    Expanded(child: items[i + 1]),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
