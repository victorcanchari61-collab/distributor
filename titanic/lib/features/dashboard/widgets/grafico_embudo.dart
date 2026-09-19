import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/tema/dimensiones.dart';
import 'grafico_util.dart';

class EtapaEmbudo {
  const EtapaEmbudo({required this.nombre, required this.valor});

  final String nombre;
  final double valor;
}

/// Embudo horizontal: cada etapa es una barra centrada, más angosta que la
/// anterior. A la derecha de cada una, qué parte de la etapa previa llegó hasta
/// ahí — ahí se ve dónde se pierde la venta.
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
            padding: EdgeInsets.only(bottom: i < etapas.length - 1 ? 8 : 0),
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

    return Row(
      children: [
        Expanded(
          child: FractionallySizedBox(
            widthFactor: ancho,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(Dimen.radioCampo),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      etapa.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    numeroEs(etapa.valor),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 44,
          child: Text(
            c == null ? '' : porcentaje(c, 0),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c == null
                  ? null
                  : c >= 85
                  ? PaletaDash.bien
                  : c >= 60
                  ? PaletaDash.alerta
                  : PaletaDash.mal,
            ),
          ),
        ),
      ],
    );
  }
}
