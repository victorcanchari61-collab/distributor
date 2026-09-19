import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/dashboard_controlador.dart';
import '../widgets/grafico_barras.dart';
import '../widgets/grafico_barras_h.dart';
import '../widgets/grafico_dona.dart';
import '../widgets/grafico_util.dart';
import '../widgets/marco_grafico.dart';
import '../widgets/tablero_pagina.dart';
import '../widgets/tarjeta_kpi.dart';

/// Qué se acaba, qué está parado y qué vence: una foto de hoy, sin rango de
/// fechas.
class InventarioDashboardPagina extends ConsumerWidget {
  const InventarioDashboardPagina({super.key});

  static const ruta = '/dashboard/inventario';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = bloqueDe(ref.watch(inventarioDashboardProvider));
    final i = b.datos;

    final criticos = i?.cobertura.where((c) => c.dias < 7).length ?? 0;
    final porVencer =
        i?.vencimientos.fold<double>(0, (a, v) => a + v.valor) ?? 0;
    final productosSalud = i?.salud.fold<double>(0, (a, s) => a + s.valor) ?? 0;

    return TableroPagina(
      ruta: ruta,
      descripcion:
          'Cuánto dura lo que hay, dónde está la plata y qué vence. Es la foto '
          'de hoy, al ritmo de venta de los últimos 30 días.',
      onRecargar: () =>
          ref.read(inventarioDashboardProvider.notifier).recargar(),
      hijos: [
        FilaKpi(
          cargando: b.cargando,
          tarjetas: [
            if (i != null) ...[
              TarjetaKpi(
                titulo: 'Inventario',
                valor: moneda(i.valorTotal),
                color: PaletaDash.serie[5],
                icono: Icons.inventory_2_outlined,
                nota: '${i.productos} productos con stock · a costo',
              ),
              TarjetaKpi(
                titulo: 'Por agotarse',
                valor: '$criticos',
                bajarEsBueno: true,
                color: PaletaDash.mal,
                icono: Icons.production_quantity_limits,
                nota: 'Duran menos de 7 días',
              ),
              TarjetaKpi(
                titulo: 'Plata parada',
                valor: moneda(i.dormidoTotal),
                bajarEsBueno: true,
                color: PaletaDash.alerta,
                icono: Icons.ac_unit,
                nota: 'Sin ventas hace 30 días',
              ),
              TarjetaKpi(
                titulo: 'Por vencer',
                valor: moneda(porVencer),
                bajarEsBueno: true,
                color: PaletaDash.mal,
                icono: Icons.event_busy_outlined,
                nota: 'Vencido o que vence en 90 días',
              ),
            ],
          ],
        ),

        MarcoGrafico(
          titulo: 'Cuánto dura el stock',
          subtitulo: i == null
              ? null
              : criticos > 0
              ? '$criticos ${criticos == 1 ? 'producto se acaba' : 'productos se acaban'} en menos de una semana al ritmo de venta actual'
              : 'Ningún producto se acaba esta semana',
          cargando: b.cargando,
          error: b.error,
          vacio: i == null || i.cobertura.isEmpty,
          mensajeVacio: 'Todavía no hay ventas para calcular el ritmo',
          alto: 280,
          contenido: () => GraficoBarrasH(
            // 60 días es el tope de la barra: más que eso es "sobra" y no
            // cambia la decisión; las marcas dicen dónde empieza el peligro.
            maximo: 60,
            referencias: const [
              (valor: 7, etiqueta: '7 días'),
              (valor: 15, etiqueta: '15 días'),
            ],
            formato: (n) => '${numeroEs(n)} d',
            items: [
              for (final c in i!.cobertura)
                ItemBarraH(
                  nombre: c.producto,
                  valor: c.dias,
                  color: semaforoCobertura(c.dias),
                  detalle: '${numeroEs(c.stock)} ${c.unidad}',
                ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Salud del stock',
          subtitulo: 'Productos según cuánto duran',
          cargando: b.cargando,
          error: b.error,
          vacio: i == null || i.salud.isEmpty,
          alto: 280,
          contenido: () => GraficoDona(
            formato: (n) => numeroEs(n),
            centro: (titulo: 'Productos', valor: numeroEs(productosSalud)),
            porciones: [
              for (final s in i!.salud)
                PorcionDona(
                  nombre: s.nombre,
                  valor: s.valor,
                  color: colorSalud(s.nombre),
                ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Dónde está la plata',
          subtitulo: i == null ? null : 'Inventario valorizado a costo: ',
          enfasis: i == null ? null : moneda(i.valorTotal),
          cargando: b.cargando,
          error: b.error,
          vacio: i == null || i.valorPorCategoria.isEmpty,
          alto: 210,
          contenido: () => GraficoDona(
            formato: compacto,
            centro: (titulo: 'Inventario', valor: compacto(i!.valorTotal)),
            porciones: [
              for (final v in i.valorPorCategoria)
                PorcionDona(nombre: v.nombre, valor: v.valor),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Plata parada',
          subtitulo: i == null
              ? null
              : i.dormidoTotal > 0
              ? '${moneda(i.dormidoTotal)} en productos sin ventas hace 30 días'
              : 'Todo lo que hay en stock se está moviendo',
          cargando: b.cargando,
          error: b.error,
          vacio: i == null || i.dormido.isEmpty,
          mensajeVacio: 'Nada parado',
          alto: 210,
          contenido: () => GraficoBarrasH(
            formato: (n) => moneda(n),
            unColor: PaletaDash.alerta,
            items: [
              for (final d in i!.dormido)
                ItemBarraH(nombre: d.nombre, valor: d.valor),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Lo que vence',
          subtitulo: i != null && porVencer > 0
              ? '${moneda(porVencer)} vencidos o por vencer en 90 días'
              : null,
          cargando: b.cargando,
          error: b.error,
          vacio: i == null || porVencer == 0,
          mensajeVacio: 'Nada vence en 90 días',
          alto: 210,
          contenido: () => GraficoBarras(
            alto: 210,
            etiquetas: i!.vencimientos
                .map((v) => v.nombre.replaceAll(' días', ' d'))
                .toList(),
            series: [
              SerieBarra(
                id: 'vence',
                nombre: 'A costo',
                color: PaletaDash.alerta,
                valores: i.vencimientos.map((v) => v.valor).toList(),
              ),
            ],
            // Del ya vencido (rojo) a lo que vence lejos (verde).
            colorDe: (_, idx) => colorDeTramo(coloresVence, idx),
            formato: (n) => moneda(n),
          ),
        ),
      ],
    );
  }
}
