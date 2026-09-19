import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/dashboard_modelos.dart';
import '../estado/dashboard_controlador.dart';
import '../widgets/grafico_barras.dart';
import '../widgets/grafico_barras_h.dart';
import '../widgets/grafico_dispersion.dart';
import '../widgets/grafico_util.dart';
import '../widgets/marco_grafico.dart';
import '../widgets/tablero_pagina.dart';
import '../widgets/tarjeta_kpi.dart';

/// Cuánto se gana, con qué margen, y qué productos conviene empujar o revisar.
class RentabilidadDashboardPagina extends ConsumerWidget {
  const RentabilidadDashboardPagina({super.key});

  static const ruta = '/dashboard/rentabilidad';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoRentabilidadProvider);
    final b = bloqueDe(ref.watch(rentabilidadDashboardProvider));
    final g = b.datos;

    final serie = g?.serie ?? const <DashDiaGanancia>[];
    final sinDatos = g == null || serie.every((d) => d.importe == 0);
    final contra = 'los ${periodo.dias} días anteriores';

    // La matriz parte el plano en la mediana de volumen y en el margen
    // general: lo que queda abajo a la derecha vende mucho pero deja menos que
    // el promedio de la casa.
    final conMargen = (g?.productos ?? const <DashProductoGanancia>[])
        .where((p) => p.margen != null)
        .toList();
    final cortX = mediana(conMargen.map((p) => p.importe).toList());
    final cortY = g?.margen ?? 0;

    Color colorDe(DashProductoGanancia p) {
      final alto = p.importe >= cortX;
      final bueno = (p.margen ?? 0) >= cortY;
      return alto && bueno
          ? PaletaDash.bien
          : alto
          ? PaletaDash.mal
          : bueno
          ? PaletaDash.serie[0]
          : PaletaDash.neutro;
    }

    final aRevisar = conMargen
        .where((p) => p.importe >= cortX && (p.margen ?? 0) < cortY)
        .toList();
    final masVendidos =
        ([...conMargen]..sort((a, c) => c.importe.compareTo(a.importe)))
            .take(5)
            .map((p) => p.nombre)
            .toSet();

    return TableroPagina(
      ruta: ruta,
      descripcion:
          'Cuánto deja lo que se vende, con el costo real de cada salida. '
          'Cada gráfico dice su conclusión debajo del título.',
      periodo: periodo,
      onPeriodo: (p) =>
          ref.read(periodoRentabilidadProvider.notifier).state = p,
      onRecargar: () =>
          ref.read(rentabilidadDashboardProvider.notifier).recargar(),
      hijos: [
        FilaKpi(
          cargando: b.cargando,
          tarjetas: [
            if (g != null) ...[
              TarjetaKpi(
                titulo: 'Ganancia',
                valor: moneda(g.ganancia),
                cambio: variacion(g.ganancia, g.gananciaAnterior),
                serie: serie.map((d) => d.ganancia).toList(),
                color: PaletaDash.serie[1],
                icono: Icons.monetization_on_outlined,
              ),
              TarjetaKpi(
                titulo: 'Margen',
                valor: g.margen != null ? porcentaje(g.margen!) : '—',
                cambio: g.margen != null && g.margenAnterior != null
                    ? variacion(g.margen!, g.margenAnterior!)
                    : null,
                color: PaletaDash.serie[2],
                icono: Icons.percent,
                nota: 'Ganancia sobre lo vendido',
              ),
              TarjetaKpi(
                titulo: 'Vendido',
                valor: moneda(g.importe),
                color: PaletaDash.serie[0],
                nota: 'Ventas del período',
              ),
              TarjetaKpi(
                titulo: 'Costo',
                valor: moneda(g.costo),
                bajarEsBueno: true,
                color: PaletaDash.serie[6],
                nota: g.lineasSinCosto > 0
                    ? '${g.lineasSinCosto} ${g.lineasSinCosto == 1 ? 'línea sin costo conocido' : 'líneas sin costo conocido'}'
                    : 'Lo que costó la mercadería vendida',
              ),
            ],
          ],
        ),

        MarcoGrafico(
          titulo: 'Ganancia y margen por día',
          subtitulo: g == null
              ? null
              : fraseVariacion(
                  variacion(g.ganancia, g.gananciaAnterior),
                  contra,
                ),
          cargando: b.cargando,
          error: b.error,
          vacio: sinDatos,
          alto: 250,
          contenido: () => GraficoBarras(
            alto: 250,
            etiquetas: serie.map((d) => diaCorto(d.fecha)).toList(),
            etiquetasLargas: serie.map((d) => diaLargo(d.fecha)).toList(),
            series: [
              SerieBarra(
                id: 'ganancia',
                nombre: 'Ganancia',
                color: PaletaDash.bien,
                valores: serie.map((d) => d.ganancia).toList(),
              ),
            ],
            // Un día en pérdida se pinta en rojo: la barra ya cuelga del cero.
            colorDe: (valor, _) => valor < 0 ? PaletaDash.mal : PaletaDash.bien,
            formato: (n) => moneda(n),
            linea: LineaSecundaria(
              nombre: 'Margen',
              color: PaletaDash.alerta,
              valores: serie.map((d) => d.margen).toList(),
              formato: (n) => '${n.round()}%',
            ),
          ),
        ),

        MarcoGrafico(
          titulo: 'Ganancia por categoría',
          subtitulo: 'Cuánto deja cada rubro',
          cargando: b.cargando,
          error: b.error,
          vacio: g == null || g.porCategoria.isEmpty,
          alto: 250,
          contenido: () => GraficoBarrasH(
            formato: (n) => moneda(n),
            items: [
              for (final i in g!.porCategoria)
                ItemBarraH(
                  nombre: i.nombre,
                  valor: i.valor,
                  color: i.valor < 0 ? PaletaDash.mal : null,
                ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Qué productos conviene empujar',
          subtitulo: g == null
              ? null
              : aRevisar.isEmpty
              ? 'Los productos que más venden dejan un margen sano'
              : '${aRevisar.length} ${aRevisar.length == 1 ? 'producto vende' : 'productos venden'} mucho y '
                    '${aRevisar.length == 1 ? 'deja' : 'dejan'} menos que el margen de la casa (${porcentaje(cortY)}): ',
          enfasis: g == null || aRevisar.isEmpty
              ? null
              : aRevisar.take(3).map((p) => p.nombre).join(', '),
          cargando: b.cargando,
          error: b.error,
          vacio: conMargen.length < 2,
          mensajeVacio: 'Hacen falta al menos dos productos vendidos',
          alto: 340,
          contenido: () => GraficoDispersion(
            alto: 320,
            etiquetaX: 'Importe vendido',
            etiquetaY: 'Margen %',
            formatoY: (n) => '${n.round()}%',
            cuadrantes: CuadrantesDispersion(
              x: cortX,
              y: cortY,
              rotulos: const [
                'Nicho rentable',
                'Estrellas',
                'Sin aporte',
                'Vende mucho, deja poco',
              ],
            ),
            puntos: [
              for (final p in conMargen)
                PuntoDispersion(
                  nombre: p.nombre,
                  x: p.importe,
                  y: p.margen ?? 0,
                  color: colorDe(p),
                  rotulo: masVendidos.contains(p.nombre) || (p.margen ?? 0) < 0,
                  detalle:
                      '${moneda(p.importe)} vendidos · ${porcentaje(p.margen ?? 0)} de margen · ${moneda(p.ganancia)} de ganancia',
                ),
            ],
          ),
        ),
      ],
    );
  }
}
