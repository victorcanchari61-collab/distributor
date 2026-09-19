import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/dashboard_modelos.dart';
import '../estado/dashboard_controlador.dart';
import '../widgets/grafico_barras.dart';
import '../widgets/grafico_dona.dart';
import '../widgets/grafico_embudo.dart';
import '../widgets/grafico_medidor.dart';
import '../widgets/grafico_util.dart';
import '../widgets/marco_grafico.dart';
import '../widgets/tablero_pagina.dart';
import '../widgets/tarjeta_kpi.dart';

/// Del pedido al cobro: cuántos se toman, cuántos se entregan completos y por
/// qué se recorta lo demás.
class RepartoDashboardPagina extends ConsumerWidget {
  const RepartoDashboardPagina({super.key});

  static const ruta = '/dashboard/reparto';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoRepartoProvider);
    final b = bloqueDe(ref.watch(repartoDashboardProvider));
    final r = b.datos;

    final serie = r?.serie ?? const <DashDiaPedidos>[];
    final sinPedidos =
        r == null ||
        serie.every((d) => d.pendientes + d.confirmados + d.anulados == 0);
    final tomados = r != null && r.embudo.isNotEmpty ? r.embudo[0].valor : 0.0;
    final convertidos = r != null && r.embudo.length > 1
        ? r.embudo[1].valor
        : 0.0;

    // Quien no puede ver Novedades recibe null: ni el KPI ni el gráfico. Antes
    // de que lleguen los datos sí se dibuja el marco (con su esqueleto), igual
    // que en el panel web: el hueco aparece y desaparece una sola vez.
    final verNovedades = r == null || r.novedadesPorMotivo != null;

    return TableroPagina(
      ruta: ruta,
      descripcion:
          'Cuántos pedidos se toman, cuántos llegan completos y por qué no. '
          'Cada gráfico dice su conclusión debajo del título.',
      periodo: periodo,
      onPeriodo: (p) => ref.read(periodoRepartoProvider.notifier).state = p,
      onRecargar: () => ref.read(repartoDashboardProvider.notifier).recargar(),
      hijos: [
        FilaKpi(
          cargando: b.cargando,
          tarjetas: [
            if (r != null) ...[
              TarjetaKpi(
                titulo: 'Pedidos tomados',
                valor: numeroEs(tomados),
                color: PaletaDash.serie[0],
                icono: Icons.assignment_outlined,
                nota: 'Sin contar los anulados',
              ),
              TarjetaKpi(
                titulo: 'Convertidos a venta',
                valor: numeroEs(convertidos),
                color: PaletaDash.serie[1],
                icono: Icons.send_outlined,
                nota: tomados > 0
                    ? '${porcentaje(convertidos / tomados * 100, 0)} de los pedidos'
                    : null,
              ),
              TarjetaKpi(
                titulo: 'Entrega completa',
                valor: r.entregaCompleta != null
                    ? porcentaje(r.entregaCompleta!, 0)
                    : '—',
                color: r.entregaCompleta != null && r.entregaCompleta! >= 90
                    ? PaletaDash.bien
                    : PaletaDash.alerta,
                icono: Icons.assignment_turned_in_outlined,
                nota: 'Sin faltantes ni recortes',
              ),
              if (r.novedadesPorMotivo != null)
                TarjetaKpi(
                  titulo: 'No entregado',
                  valor: moneda(r.importeNovedades),
                  bajarEsBueno: true,
                  color: PaletaDash.mal,
                  icono: Icons.unpublished_outlined,
                  nota: 'Mercadería que no llegó al cliente',
                ),
            ],
          ],
        ),

        MarcoGrafico(
          titulo: 'Pedidos por día',
          subtitulo: 'Cuántos se toman y en qué quedan',
          cargando: b.cargando,
          error: b.error,
          vacio: sinPedidos,
          alto: 240,
          contenido: () => GraficoBarras(
            alto: 240,
            apilado: true,
            etiquetas: serie.map((d) => diaCorto(d.fecha)).toList(),
            etiquetasLargas: serie.map((d) => diaLargo(d.fecha)).toList(),
            series: [
              SerieBarra(
                id: 'conf',
                nombre: 'Convertidos a venta',
                color: PaletaDash.bien,
                valores: serie.map((d) => d.confirmados.toDouble()).toList(),
              ),
              SerieBarra(
                id: 'pend',
                nombre: 'Pendientes',
                color: PaletaDash.alerta,
                valores: serie.map((d) => d.pendientes.toDouble()).toList(),
              ),
              SerieBarra(
                id: 'anu',
                nombre: 'Anulados',
                color: PaletaDash.neutro,
                valores: serie.map((d) => d.anulados.toDouble()).toList(),
              ),
            ],
            formato: (n) => numeroEs(n),
            formatoEje: (n) => numeroEs(n),
          ),
        ),

        // Sin `vacio`: sin entregas el medidor dice "—", que ya es la respuesta.
        MarcoGrafico(
          titulo: 'Entregas completas',
          subtitulo: 'De lo entregado, lo que llegó sin recortes',
          cargando: b.cargando,
          error: b.error,
          alto: 190,
          contenido: () => Center(
            child: GraficoMedidor(
              valor: r?.entregaCompleta,
              titulo: 'sin faltantes ni recortes',
              meta: 90,
            ),
          ),
        ),

        MarcoGrafico(
          titulo: 'Del pedido al cobro',
          subtitulo:
              'A la derecha, qué parte de la etapa anterior llegó hasta ahí',
          cargando: b.cargando,
          error: b.error,
          vacio: sinPedidos,
          alto: 210,
          contenido: () => GraficoEmbudo(
            etapas: [
              for (final e in r!.embudo)
                EtapaEmbudo(nombre: e.nombre, valor: e.valor),
            ],
          ),
        ),

        if (verNovedades)
          MarcoGrafico(
            titulo: 'Por qué no llegó completo',
            subtitulo: r != null && r.importeNovedades > 0
                ? '${moneda(r.importeNovedades)} en mercadería que no se entregó'
                : null,
            cargando: b.cargando,
            error: b.error,
            vacio: r == null || (r.novedadesPorMotivo?.isEmpty ?? true),
            mensajeVacio: 'Sin novedades en el período',
            alto: 210,
            contenido: () => GraficoDona(
              formato: compacto,
              centro: (
                titulo: 'No entregado',
                valor: moneda(r!.importeNovedades),
              ),
              porciones: [
                for (final n in r.novedadesPorMotivo!)
                  PorcionDona(nombre: n.nombre, valor: n.valor),
              ],
            ),
          ),
      ],
    );
  }
}
