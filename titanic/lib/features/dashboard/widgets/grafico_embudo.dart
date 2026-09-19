import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import 'grafico_util.dart';

class EtapaEmbudo {
  const EtapaEmbudo({required this.nombre, required this.valor});

  final String nombre;
  final double valor;
}

/// Embudo horizontal: cada etapa es una barra centrada, más angosta que la
/// anterior. A la derecha del nombre de cada una, qué parte de la etapa previa
/// llegó hasta ahí — ahí se ve dónde se pierde la venta.
///
/// El nombre va sobre la barra y no dentro: en un teléfono la última etapa
/// queda tan angosta que "Cobrados del todo" se leería "C…".
class GraficoEmbudo extends StatelessWidget {
  const GraficoEmbudo({super.key, required this.etapas});

  final List<EtapaEmbudo> etapas;

  @override
  Widget build(BuildContext context) {
    if (etapas.isEmpty) return const SizedBox.shrink();

    // Sin pedidos la primera etapa vale cero: el 1 evita dividir entre cero y
    // deja todas las barras en su ancho mínimo.
    final primero = math.max(etapas.first.valor, 1.0);

    return Column(
      children: [
        for (var i = 0; i < etapas.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < etapas.length - 1 ? 10 : 0),
            child: _Etapa(
              etapa: etapas[i],
              color: PaletaDash.deSerie(i),
              ancho: math.max(0.22, etapas[i].valor / primero).clamp(0.22, 1.0),
              conversion: i > 0 && etapas[i - 1].valor > 0
                  ? etapas[i].valor / etapas[i - 1].valor * 100
                  : null,
            ),
          ),
      ],
    );
  }
}

class _Etapa extends StatelessWidget {
  const _Etapa({
    required this.etapa,
    required this.color,
    required this.ancho,
    required this.conversion,
  });

  final EtapaEmbudo etapa;
  final Color color;
  final double ancho;
  final double? conversion;

  @override
  Widget build(BuildContext context) {
    final c = conversion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                etapa.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
            if (c != null)
              Text(
                porcentaje(c, 0),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c >= 85
                      ? PaletaDash.bien
                      : c >= 60
                      ? PaletaDash.alerta
                      : PaletaDash.mal,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        FractionallySizedBox(
          widthFactor: ancho,
          alignment: Alignment.center,
          child: Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
            ),
            child: Text(
              numeroEs(etapa.valor),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
