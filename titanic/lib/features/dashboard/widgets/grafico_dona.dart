import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';
import 'grafico_util.dart';

class PorcionDona {
  const PorcionDona({required this.nombre, required this.valor, this.color});

  final String nombre;
  final double valor;

  /// Color de la porción; si no, el de la paleta según su posición.
  final Color? color;
}

/// Dona con leyenda. Tocar una porción, o su fila en la leyenda, la resalta y
/// pone en el centro su nombre, su valor y qué parte del total es.
///
/// En un teléfono la leyenda va debajo de la dona: al lado no cabe en 320 px.
class GraficoDona extends StatefulWidget {
  const GraficoDona({
    super.key,
    required this.porciones,
    this.formato = compacto,
    this.centro,
    this.tamano = 168,
  });

  final List<PorcionDona> porciones;

  /// Cómo se escribe el valor en la leyenda.
  final String Function(double) formato;

  /// Lo que va en el centro cuando no hay ninguna porción elegida: el total,
  /// por ejemplo.
  final ({String titulo, String valor})? centro;
  final double tamano;

  @override
  State<GraficoDona> createState() => _GraficoDonaState();
}

class _GraficoDonaState extends State<GraficoDona> {
  int? _activa;

  Color _color(int i) => widget.porciones[i].color ?? PaletaDash.deSerie(i);

  @override
  void didUpdateWidget(GraficoDona anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.porciones != widget.porciones) _activa = null;
  }

  @override
  Widget build(BuildContext context) {
    final porciones = widget.porciones;
    if (porciones.isEmpty) return const SizedBox.shrink();

    final total = porciones.fold<double>(0, (a, p) => a + math.max(0, p.valor));
    final activa = _activa != null && _activa! < porciones.length
        ? _activa
        : null;

    final dona = SizedBox(
      width: widget.tamano,
      height: widget.tamano,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (total > 0)
            _anillo(porciones, total, activa)
          else
            // Con todo en cero no hay nada que repartir: solo el aro vacío.
            Container(
              width: widget.tamano - 8,
              height: widget.tamano - 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: PaletaDash.fondoSuave, width: 20),
              ),
            ),
          IgnorePointer(child: _centro(porciones, total, activa)),
        ],
      ),
    );

    final leyenda = Column(
      children: [
        for (var i = 0; i < porciones.length; i++)
          _FilaLeyenda(
            porcion: porciones[i],
            color: _color(i),
            texto: widget.formato(porciones[i].valor),
            porcentaje: total > 0
                ? porcentaje(math.max(0, porciones[i].valor) / total * 100, 0)
                : '—',
            activa: activa == i,
            alTocar: () => setState(() => _activa = activa == i ? null : i),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, caja) {
        if (caja.maxWidth >= 440) {
          return Row(
            children: [
              dona,
              const SizedBox(width: 24),
              Expanded(child: leyenda),
            ],
          );
        }
        return Column(children: [dona, const SizedBox(height: 12), leyenda]);
      },
    );
  }

  Widget _anillo(List<PorcionDona> porciones, double total, int? activa) {
    final radio = widget.tamano / 2 - 14;
    final variasConValor = porciones.where((p) => p.valor > 0).length > 1;

    return PieChart(
      duration: Duration.zero,
      PieChartData(
        startDegreeOffset: -90,
        // Sin separación cuando hay una sola porción: un aro partido por una
        // rendija no dice nada.
        sectionsSpace: variasConValor ? 2 : 0,
        centerSpaceRadius: radio - 10,
        sections: [
          for (var i = 0; i < porciones.length; i++)
            PieChartSectionData(
              value: math.max(0, porciones[i].valor),
              color: _color(
                i,
              ).withValues(alpha: activa != null && activa != i ? 0.4 : 1),
              radius: activa == i ? 24 : 20,
              showTitle: false,
            ),
        ],
        pieTouchData: PieTouchData(
          touchCallback: (evento, respuesta) {
            final i = respuesta?.touchedSection?.touchedSectionIndex ?? -1;
            if (i >= 0) {
              if (i != _activa) setState(() => _activa = i);
            } else if (evento is FlTapUpEvent && _activa != null) {
              // Se tocó el centro o fuera del aro: se suelta la selección.
              setState(() => _activa = null);
            }
          },
        ),
      ),
    );
  }

  Widget _centro(List<PorcionDona> porciones, double total, int? activa) {
    final elegida = activa != null ? porciones[activa] : null;
    final titulo = elegida?.nombre ?? widget.centro?.titulo ?? 'Total';
    final valor = elegida != null
        ? widget.formato(elegida.valor)
        : (widget.centro?.valor ?? widget.formato(total));

    return SizedBox(
      width: widget.tamano - 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
              color: Colores.tintaSuave,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 18,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: Colores.tinta,
              ),
            ),
          ),
          if (elegida != null && total > 0)
            Text(
              porcentaje(math.max(0, elegida.valor) / total * 100),
              style: const TextStyle(fontSize: 11, color: Colores.tintaSuave),
            ),
        ],
      ),
    );
  }
}

class _FilaLeyenda extends StatelessWidget {
  const _FilaLeyenda({
    required this.porcion,
    required this.color,
    required this.texto,
    required this.porcentaje,
    required this.activa,
    required this.alTocar,
  });

  final PorcionDona porcion;
  final Color color;
  final String texto;
  final String porcentaje;
  final bool activa;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: activa ? PaletaDash.fondoSuave : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                porcion.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: texto,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colores.tinta,
                    ),
                  ),
                  TextSpan(
                    text: '  $porcentaje',
                    style: const TextStyle(color: Colores.tintaTenue),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
