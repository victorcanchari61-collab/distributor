import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/dashboard_modelos.dart';
import '../estado/dashboard_controlador.dart';
import '../widgets/grafico_barras.dart';
import '../widgets/grafico_barras_h.dart';
import '../widgets/grafico_calor.dart';
import '../widgets/grafico_dona.dart';
import '../widgets/grafico_linea.dart';
import '../widgets/grafico_util.dart';
import '../widgets/marco_grafico.dart';
import '../widgets/tablero_pagina.dart';
import '../widgets/tarjeta_kpi.dart';

/// Cuánto se vende, a quién, quién lo vende y en qué momento — con el mes
/// proyectado a su cierre.
class VentasDashboardPagina extends ConsumerWidget {
  const VentasDashboardPagina({super.key});

  static const ruta = '/dashboard/ventas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoVentasProvider);
    final b = bloqueDe(ref.watch(ventasDashboardProvider));
    final v = b.datos;

    final contra = 'los ${periodo.dias} días anteriores';
    final serie = v?.serie ?? const <DashDiaVenta>[];
    final sinVentas = v == null || serie.every((d) => d.importe == 0);

    final mes = v?.mes;
    final diasMes = mes?.diasMes ?? 0;
    List<double?> relleno(List<double?> valores) => [
      for (var i = 0; i < diasMes; i++) i < valores.length ? valores[i] : null,
    ];
    // El cierre proyectado es el último día de la proyección; si el backend no
    // la trae completa, lo acumulado hasta hoy.
    final cierre = mes == null
        ? 0.0
        : (diasMes > 0 && diasMes - 1 < mes.serieProyeccion.length
                  ? mes.serieProyeccion[diasMes - 1]
                  : null) ??
              mes.acumulado;

    final pareto = v?.pareto ?? const <DashPareto>[];

    return TableroPagina(
      ruta: VentasDashboardPagina.ruta,
      descripcion:
          'Cuánto se vende, a quién, quién lo vende y cuándo. Cada gráfico '
          'dice su conclusión debajo del título.',
      periodo: periodo,
      onPeriodo: (p) => ref.read(periodoVentasProvider.notifier).state = p,
      onRecargar: () => ref.read(ventasDashboardProvider.notifier).recargar(),
      hijos: [
        FilaKpi(
          cargando: b.cargando,
          tarjetas: [
            if (v != null) ...[
              TarjetaKpi(
                titulo: 'Ventas',
                valor: moneda(v.actual.importe),
                cambio: variacion(v.actual.importe, v.anterior.importe),
                serie: serie.map((d) => d.importe).toList(),
                color: PaletaDash.serie[0],
                icono: Icons.monetization_on_outlined,
              ),
              TarjetaKpi(
                titulo: 'Ticket promedio',
                valor: moneda(v.actual.ticket),
                cambio: variacion(v.actual.ticket, v.anterior.ticket),
                color: PaletaDash.serie[4],
                nota: 'Lo que deja una venta en promedio',
              ),
              TarjetaKpi(
                titulo: 'Ventas realizadas',
                valor: numeroEs(v.actual.notas.toDouble()),
                cambio: variacion(
                  v.actual.notas.toDouble(),
                  v.anterior.notas.toDouble(),
                ),
                serie: serie.map((d) => d.notas.toDouble()).toList(),
                color: PaletaDash.serie[5],
              ),
              TarjetaKpi(
                titulo: 'Clientes que compraron',
                valor: numeroEs(v.actual.clientes.toDouble()),
                cambio: variacion(
                  v.actual.clientes.toDouble(),
                  v.anterior.clientes.toDouble(),
                ),
                color: PaletaDash.serie[2],
                icono: Icons.people_outline,
              ),
            ],
          ],
        ),

        MarcoGrafico(
          titulo: 'Ventas por día',
          subtitulo: v == null
              ? null
              : '${fraseVariacion(variacion(v.actual.importe, v.anterior.importe), contra)}'
                    '${v.atipicos.isEmpty ? '' : ' · ${v.atipicos.length} ${v.atipicos.length == 1 ? 'día fuera de lo normal' : 'días fuera de lo normal'}'}',
          cargando: b.cargando,
          error: b.error,
          vacio: sinVentas,
          alto: 250,
          contenido: () => GraficoLinea(
            alto: 250,
            etiquetas: serie.map((d) => diaCorto(d.fecha)).toList(),
            etiquetasLargas: serie.map((d) => diaLargo(d.fecha)).toList(),
            formato: (n) => moneda(n),
            series: [
              SerieLinea(
                id: 'actual',
                nombre: 'Este período',
                color: PaletaDash.serie[0],
                valores: serie.map((d) => d.importe).toList(),
                area: true,
              ),
              SerieLinea(
                id: 'anterior',
                nombre: 'Período anterior',
                color: PaletaDash.neutro,
                valores: serie.map((d) => d.importeAnterior).toList(),
                punteada: true,
                grosor: 1.5,
              ),
            ],
            // Verde el día que se pasó de lo normal para arriba, rojo para abajo.
            marcas: [
              for (final a in v?.atipicos ?? const <DashAtipico>[])
                MarcaLinea(
                  indice: a.indice,
                  serie: 'actual',
                  color: a.esPico ? PaletaDash.bien : PaletaDash.mal,
                  titulo: a.esPico
                      ? 'Día muy por encima de lo normal'
                      : 'Día muy por debajo de lo normal',
                ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: mes != null && mes.nombre.isNotEmpty
              ? 'Avance de ${mes.nombre}'
              : 'Avance del mes',
          subtitulo: mes == null ? null : 'Cierre proyectado ',
          enfasis: mes == null ? null : moneda(cierre),
          sufijo: mes == null
              ? null
              : ' · ${fraseVariacion(variacion(mes.acumulado, mes.mesAnteriorMismoPunto), 'el mes pasado a esta fecha')}',
          cargando: b.cargando,
          error: b.error,
          vacio:
              mes == null ||
              diasMes == 0 ||
              (mes.acumulado == 0 && mes.mesAnterior == 0),
          alto: 250,
          contenido: () => GraficoLinea(
            alto: 250,
            etiquetas: [for (var i = 0; i < diasMes; i++) '${i + 1}'],
            etiquetasLargas: [for (var i = 0; i < diasMes; i++) 'Día ${i + 1}'],
            formato: (n) => moneda(n),
            series: [
              SerieLinea(
                id: 'anterior',
                nombre: 'Mes pasado',
                color: PaletaDash.neutro,
                valores: relleno(mes!.serieAnterior),
                grosor: 1.5,
              ),
              SerieLinea(
                id: 'actual',
                nombre: 'Este mes',
                color: PaletaDash.serie[0],
                valores: relleno(mes.serieActual),
                area: true,
              ),
              SerieLinea(
                id: 'proyeccion',
                nombre: 'Proyección',
                color: PaletaDash.serie[0],
                valores: relleno(mes.serieProyeccion),
                punteada: true,
              ),
            ],
            marcas: [
              MarcaLinea(
                indice: diasMes - 1,
                serie: 'proyeccion',
                color: PaletaDash.serie[0],
                titulo: 'Cierre proyectado ${moneda(cierre)}',
              ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Cuándo se vende',
          subtitulo: 'Cuanto más oscuro, más se vende en esa hora',
          cargando: b.cargando,
          error: b.error,
          vacio: v == null || v.calor.isEmpty,
          alto: 210,
          contenido: () => GraficoCalor(
            color: PaletaDash.serie[0],
            celdas: [
              for (final c in v!.calor)
                CeldaCalor(
                  dia: c.dia,
                  hora: c.hora,
                  valor: c.importe,
                  detalle:
                      '${moneda(c.importe)} · ${c.notas} ${c.notas == 1 ? 'venta' : 'ventas'}',
                ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Clientes que sostienen las ventas',
          subtitulo: v != null && v.clientesTotal > 0
              ? '${v.clientesAl80} de ${v.clientesTotal} clientes hacen el 80% de lo vendido'
              : null,
          cargando: b.cargando,
          error: b.error,
          vacio: pareto.isEmpty,
          alto: 220,
          contenido: () => GraficoBarras(
            alto: 220,
            etiquetas: [for (var i = 0; i < pareto.length; i++) '${i + 1}'],
            etiquetasLargas: pareto.map((p) => p.nombre).toList(),
            series: [
              SerieBarra(
                id: 'venta',
                nombre: 'Ventas',
                color: PaletaDash.serie[0],
                valores: pareto.map((p) => p.valor).toList(),
              ),
            ],
            formato: (n) => moneda(n),
            // El acumulado es un porcentaje: su eje va de 0 a 100 aparte del de
            // las barras (que es dinero).
            linea: LineaSecundaria(
              nombre: 'Acumulado',
              color: PaletaDash.alerta,
              valores: pareto.map<double?>((p) => p.acumulado).toList(),
              formato: (n) => '${n.round()}%',
              max: 100,
            ),
          ),
        ),

        MarcoGrafico(
          titulo: 'Quién vende',
          subtitulo: 'Importe por vendedor',
          cargando: b.cargando,
          error: b.error,
          vacio: v == null || v.porVendedor.isEmpty,
          alto: 180,
          contenido: () => GraficoBarrasH(
            formato: (n) => moneda(n),
            items: [
              for (final i in v!.porVendedor)
                ItemBarraH(
                  nombre: i.nombre,
                  valor: i.valor,
                  detalle: '${i.cantidad}',
                  color: i.nombre.startsWith('Sin ') ? PaletaDash.neutro : null,
                ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Qué se vende',
          subtitulo: 'Por categoría',
          cargando: b.cargando,
          error: b.error,
          vacio: v == null || v.porCategoria.isEmpty,
          alto: 180,
          contenido: () => GraficoDona(
            formato: compacto,
            centro: (titulo: 'Vendido', valor: moneda(v!.actual.importe)),
            porciones: [
              for (final i in v.porCategoria)
                PorcionDona(
                  nombre: i.nombre,
                  valor: i.valor,
                  color: i.nombre.startsWith('Sin ') ? PaletaDash.neutro : null,
                ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Contado y crédito',
          subtitulo: 'Cómo pagan los clientes',
          cargando: b.cargando,
          error: b.error,
          vacio: v == null || v.porFormaPago.isEmpty,
          alto: 180,
          contenido: () => GraficoDona(
            formato: compacto,
            porciones: [
              for (final i in v!.porFormaPago)
                PorcionDona(
                  nombre: i.nombre,
                  valor: i.valor,
                  color: i.nombre == 'Crédito'
                      ? PaletaDash.alerta
                      : PaletaDash.bien,
                ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Lo que más se vende',
          subtitulo: 'Los 10 productos con más importe',
          cargando: b.cargando,
          error: b.error,
          vacio: v == null || v.topProductos.isEmpty,
          alto: 200,
          contenido: () => GraficoBarrasH(
            formato: (n) => moneda(n),
            unColor: PaletaDash.serie[0],
            items: [
              for (final i in v!.topProductos)
                ItemBarraH(nombre: i.nombre, valor: i.valor),
            ],
          ),
        ),
      ],
    );
  }
}
