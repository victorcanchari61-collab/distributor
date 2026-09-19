import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/dashboard_modelos.dart';
import '../estado/dashboard_controlador.dart';
import '../widgets/grafico_barras.dart';
import '../widgets/grafico_barras_h.dart';
import '../widgets/grafico_util.dart';
import '../widgets/marco_grafico.dart';
import '../widgets/tablero_pagina.dart';
import '../widgets/tarjeta_kpi.dart';

/// Cuánto se debe, hace cuánto, quién y cuánto se cobró — para saber a quién
/// llamar primero.
class CobranzaDashboardPagina extends ConsumerWidget {
  const CobranzaDashboardPagina({super.key});

  static const ruta = '/dashboard/cobranza';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoCobranzaProvider);
    final b = bloqueDe(ref.watch(cobranzaDashboardProvider));
    final c = b.datos;

    final cobros = c?.cobros ?? const <DashCobroDia>[];
    final antiguedad = c?.antiguedad ?? const <DashItem>[];
    final sinDeuda = c == null || c.totalPorCobrar == 0;

    // Los tramos son de lo reciente a lo viejo; los dos últimos (31–60 y más de
    // 60) son lo que pasa de un mes. Se suman "desde el cuarto" y no por
    // posición exacta para no romper si el backend cambia la cantidad.
    final vieja = antiguedad.skip(3).fold<double>(0, (a, t) => a + t.valor);
    final conDeuda = antiguedad.where((a) => a.valor > 0).toList();
    final masVieja = conDeuda.isEmpty ? null : conDeuda.last;
    final pasadoDeUnMes = c != null && c.totalPorCobrar > 0
        ? vieja / c.totalPorCobrar * 100
        : 0.0;

    return TableroPagina(
      ruta: ruta,
      descripcion:
          'Lo que se debe, hace cuánto y lo que se ha cobrado. Cada gráfico '
          'dice su conclusión debajo del título.',
      periodo: periodo,
      onPeriodo: (p) => ref.read(periodoCobranzaProvider.notifier).state = p,
      onRecargar: () => ref.read(cobranzaDashboardProvider.notifier).recargar(),
      hijos: [
        FilaKpi(
          cargando: b.cargando,
          tarjetas: [
            if (c != null) ...[
              TarjetaKpi(
                titulo: 'Por cobrar',
                valor: moneda(c.totalPorCobrar),
                bajarEsBueno: true,
                color: PaletaDash.serie[2],
                icono: Icons.account_balance_wallet_outlined,
                nota: '${c.cuentas} notas · ${c.clientes} clientes',
              ),
              TarjetaKpi(
                titulo: 'Deuda de más de 30 días',
                valor: c.totalPorCobrar > 0
                    ? porcentaje(pasadoDeUnMes, 0)
                    : '0%',
                bajarEsBueno: true,
                color: PaletaDash.mal,
                icono: Icons.event_busy_outlined,
                nota: vieja > 0
                    ? '${moneda(vieja)} sin cobrar hace más de un mes'
                    : 'Nada atrasado',
              ),
              TarjetaKpi(
                titulo: 'Cobrado',
                valor: moneda(c.cobradoPeriodo),
                color: PaletaDash.serie[1],
                icono: Icons.payments_outlined,
                nota: 'En el período elegido',
              ),
              TarjetaKpi(
                titulo: 'Crédito otorgado',
                valor: moneda(c.creditoOtorgado),
                color: PaletaDash.serie[4],
                nota: 'Vendido a crédito en el período',
              ),
            ],
          ],
        ),

        MarcoGrafico(
          titulo: 'Cuánto hace que se debe',
          subtitulo: c == null
              ? null
              : sinDeuda
              ? 'Nadie debe nada'
              : '${porcentaje(pasadoDeUnMes, 0)} de la deuda pasa de 30 días',
          cargando: b.cargando,
          error: b.error,
          vacio: sinDeuda,
          mensajeVacio: 'Sin cuentas por cobrar',
          alto: 240,
          contenido: () => GraficoBarras(
            alto: 240,
            // "Más de 60" se lee "> 60" en el eje: con cinco barras en un
            // teléfono cada etiqueta tiene ~50 px y la larga obligaba a saltarse
            // las del medio. El globo sigue diciendo el nombre completo.
            etiquetas: antiguedad
                .map(
                  (a) => a.nombre
                      .replaceAll(' días', ' d')
                      .replaceAll('Más de ', '> '),
                )
                .toList(),
            etiquetasLargas: antiguedad
                .map(
                  (a) =>
                      '${a.nombre} · ${a.cantidad} ${a.cantidad == 1 ? 'nota' : 'notas'}',
                )
                .toList(),
            series: [
              SerieBarra(
                id: 'deuda',
                nombre: 'Por cobrar',
                color: PaletaDash.alerta,
                valores: antiguedad.map((a) => a.valor).toList(),
              ),
            ],
            // De verde (reciente) a rojo (vencido): cada tramo su color.
            colorDe: (_, i) => colorDeTramo(coloresDeuda, i),
            formato: (n) => moneda(n),
          ),
        ),

        MarcoGrafico(
          titulo: 'Quién debe más',
          subtitulo: masVieja == null
              ? null
              : 'La deuda más vieja tiene ${masVieja.nombre == 'Más de 60' ? 'más de 60 días' : masVieja.nombre}',
          cargando: b.cargando,
          error: b.error,
          vacio: c == null || c.deudores.isEmpty,
          mensajeVacio: 'Sin deudores',
          alto: 240,
          contenido: () => GraficoBarrasH(
            formato: (n) => moneda(n),
            items: [
              for (final d in c!.deudores)
                ItemBarraH(
                  nombre: d.cliente,
                  valor: d.saldo,
                  color: semaforoDias(d.dias),
                  detalle: '${d.dias} d',
                ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Cobros por día',
          subtitulo: c == null
              ? null
              : 'Por método de pago · a crédito se dio ${moneda(c.creditoOtorgado)}',
          cargando: b.cargando,
          error: b.error,
          vacio: c == null || c.metodos.isEmpty,
          mensajeVacio: 'Sin cobros en el período',
          alto: 240,
          contenido: () => GraficoBarras(
            alto: 240,
            apilado: true,
            etiquetas: cobros.map((d) => diaCorto(d.fecha)).toList(),
            etiquetasLargas: cobros.map((d) => diaLargo(d.fecha)).toList(),
            series: [
              for (var i = 0; i < c!.metodos.length; i++)
                SerieBarra(
                  id: c.metodos[i],
                  nombre: c.metodos[i],
                  color: PaletaDash.deSerie(i),
                  valores: [
                    for (final d in cobros)
                      i < d.valores.length ? d.valores[i] : 0.0,
                  ],
                ),
            ],
            formato: (n) => moneda(n),
          ),
        ),
      ],
    );
  }
}
