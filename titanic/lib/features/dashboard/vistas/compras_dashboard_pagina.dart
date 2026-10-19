import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/dashboard_modelos.dart';
import '../estado/dashboard_controlador.dart';
import '../widgets/grafico_barras.dart';
import '../widgets/grafico_barras_h.dart';
import '../widgets/grafico_dona.dart';
import '../widgets/grafico_util.dart';
import '../widgets/marco_grafico.dart';
import '../widgets/tablero_pagina.dart';
import '../widgets/tarjeta_kpi.dart';

/// El otro lado de Cobranza: lo que se le debe a los proveedores y hace
/// cuánto, lo que se compra y a quién, y qué productos están costando más —
/// para saber a quién pagar primero y dónde negociar.
class ComprasDashboardPagina extends ConsumerWidget {
  const ComprasDashboardPagina({super.key});

  static const ruta = '/dashboard/compras';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoComprasProvider);
    final b = bloqueDe(ref.watch(comprasDashboardProvider));
    final c = b.datos;

    final serie = c?.serie ?? const <DashDiaCompra>[];
    final pagos = c?.pagos ?? const <DashCobroDia>[];
    final antiguedad = c?.antiguedad ?? const <DashItem>[];
    final costos = c?.costos ?? const <DashCostoProducto>[];
    final sinDeuda = c == null || c.totalPorPagar == 0;
    final sinCompras =
        c == null || serie.every((d) => d.contado == 0 && d.credito == 0);

    // Igual que en Cobranza: los dos últimos tramos (31–60 y más de 60) son lo
    // que pasa de un mes, y se suman "desde el cuarto" para no romper si el
    // backend cambia la cantidad de tramos.
    final vieja = antiguedad.skip(3).fold<double>(0, (a, t) => a + t.valor);
    final conDeuda = antiguedad.where((a) => a.valor > 0).toList();
    final masVieja = conDeuda.isEmpty ? null : conDeuda.last;
    final pasadoDeUnMes = c != null && c.totalPorPagar > 0
        ? vieja / c.totalPorPagar * 100
        : 0.0;

    final principal = c == null || c.porProveedor.isEmpty
        ? null
        : c.porProveedor.first;

    // "3 subieron, 1 bajó": la conclusión de la lista de costos. Uno que no
    // cambió no suma a ninguno de los dos lados.
    final subieron = costos.where((x) => x.variacion > 0).length;
    final bajaron = costos.where((x) => x.variacion < 0).length;
    final cambios = [
      if (subieron > 0) '$subieron ${subieron == 1 ? 'subió' : 'subieron'}',
      if (bajaron > 0) '$bajaron ${bajaron == 1 ? 'bajó' : 'bajaron'}',
    ];

    String compras(int n) => '$n ${n == 1 ? 'compra' : 'compras'}';

    return TableroPagina(
      ruta: ruta,
      descripcion:
          'Lo que se debe a proveedores, lo que se compra y cómo cambian los '
          'costos.',
      periodo: periodo,
      onPeriodo: (p) => ref.read(periodoComprasProvider.notifier).state = p,
      onRecargar: () => ref.read(comprasDashboardProvider.notifier).recargar(),
      hijos: [
        FilaKpi(
          cargando: b.cargando,
          tarjetas: [
            if (c != null) ...[
              TarjetaKpi(
                titulo: 'Por pagar',
                valor: moneda(c.totalPorPagar),
                bajarEsBueno: true,
                color: PaletaDash.serie[2],
                icono: Icons.account_balance_wallet_outlined,
                nota:
                    '${compras(c.cuentas)} · ${c.proveedores} '
                    '${c.proveedores == 1 ? 'proveedor' : 'proveedores'}',
              ),
              TarjetaKpi(
                titulo: 'Deuda de más de 30 días',
                valor: c.totalPorPagar > 0
                    ? porcentaje(pasadoDeUnMes, 0)
                    : '0%',
                bajarEsBueno: true,
                color: PaletaDash.mal,
                icono: Icons.event_busy_outlined,
                nota: vieja > 0
                    ? '${moneda(vieja)} sin pagar hace más de un mes'
                    : 'Nada atrasado',
              ),
              // Comprar más no es bueno ni malo por sí solo, pero el cambio se
              // lee como en Ventas: verde si sube. Sin período anterior con
              // compras no hay chip (variacion devuelve null).
              TarjetaKpi(
                titulo: 'Comprado',
                valor: moneda(c.comprado),
                cambio: variacion(c.comprado, c.compradoAnterior),
                color: PaletaDash.serie[4],
                icono: Icons.shopping_bag_outlined,
                nota: c.porRecibir > 0
                    ? '${compras(c.compras)} · ${moneda(c.porRecibir)} por recibir'
                    : '${compras(c.compras)} en el período',
              ),
              TarjetaKpi(
                titulo: 'Pagado',
                valor: moneda(c.pagadoPeriodo),
                color: PaletaDash.serie[1],
                icono: Icons.payments_outlined,
                nota: 'A proveedores en el período',
              ),
            ],
          ],
        ),

        MarcoGrafico(
          titulo: 'Cuánto hace que se debe',
          subtitulo: c == null
              ? null
              : sinDeuda
              ? 'No se le debe a nadie'
              : '${porcentaje(pasadoDeUnMes, 0)} de la deuda pasa de 30 días',
          cargando: b.cargando,
          error: b.error,
          vacio: sinDeuda,
          mensajeVacio: 'Sin cuentas por pagar',
          alto: 240,
          contenido: () => GraficoBarras(
            alto: 240,
            // Las mismas etiquetas cortas que Cobranza: "> 60" en el eje para
            // que las cinco quepan en un teléfono; el globo dice el nombre
            // completo.
            etiquetas: antiguedad
                .map(
                  (a) => a.nombre
                      .replaceAll(' días', ' d')
                      .replaceAll('Más de ', '> '),
                )
                .toList(),
            etiquetasLargas: antiguedad
                .map((a) => '${a.nombre} · ${compras(a.cantidad)}')
                .toList(),
            series: [
              SerieBarra(
                id: 'deuda',
                nombre: 'Por pagar',
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
          titulo: 'A quién se le debe más',
          subtitulo: masVieja == null
              ? null
              : 'La deuda más vieja tiene ${masVieja.nombre == 'Más de 60' ? 'más de 60 días' : masVieja.nombre}',
          cargando: b.cargando,
          error: b.error,
          vacio: c == null || c.acreedores.isEmpty,
          mensajeVacio: 'Sin deudas con proveedores',
          alto: 240,
          contenido: () => GraficoBarrasH(
            formato: (n) => moneda(n),
            items: [
              for (final a in c!.acreedores)
                ItemBarraH(
                  nombre: a.proveedor,
                  valor: a.saldo,
                  color: semaforoDias(a.dias),
                  detalle: '${a.dias} d',
                ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Compras por día',
          subtitulo: c == null
              ? null
              : fraseVariacion(
                  variacion(c.comprado, c.compradoAnterior),
                  'los ${periodo.dias} días anteriores',
                ),
          cargando: b.cargando,
          error: b.error,
          vacio: sinCompras,
          mensajeVacio: 'Sin compras en el período',
          alto: 240,
          contenido: () => GraficoBarras(
            alto: 240,
            apilado: true,
            etiquetas: serie.map((d) => diaCorto(d.fecha)).toList(),
            etiquetasLargas: serie.map((d) => diaLargo(d.fecha)).toList(),
            // Los colores de "Contado y crédito" de Ventas: el crédito es lo
            // que después habrá que pagar.
            series: [
              SerieBarra(
                id: 'contado',
                nombre: 'Contado',
                color: PaletaDash.bien,
                valores: serie.map((d) => d.contado).toList(),
              ),
              SerieBarra(
                id: 'credito',
                nombre: 'Crédito',
                color: PaletaDash.alerta,
                valores: serie.map((d) => d.credito).toList(),
              ),
            ],
            formato: (n) => moneda(n),
          ),
        ),

        MarcoGrafico(
          titulo: 'Pagos por día',
          subtitulo: c == null
              ? null
              : 'Por método de pago · a crédito se compró ${moneda(c.compradoCredito)}',
          cargando: b.cargando,
          error: b.error,
          vacio: c == null || c.metodos.isEmpty,
          mensajeVacio: 'Sin pagos en el período',
          alto: 240,
          contenido: () => GraficoBarras(
            alto: 240,
            apilado: true,
            etiquetas: pagos.map((d) => diaCorto(d.fecha)).toList(),
            etiquetasLargas: pagos.map((d) => diaLargo(d.fecha)).toList(),
            series: [
              for (var i = 0; i < c!.metodos.length; i++)
                SerieBarra(
                  id: c.metodos[i],
                  nombre: c.metodos[i],
                  color: PaletaDash.deSerie(i),
                  valores: [
                    for (final d in pagos)
                      i < d.valores.length ? d.valores[i] : 0.0,
                  ],
                ),
            ],
            formato: (n) => moneda(n),
          ),
        ),

        MarcoGrafico(
          titulo: 'A quién se le compra',
          subtitulo: c == null
              ? null
              : principal != null && c.comprado > 0
              ? '${principal.nombre} es el ${porcentaje(principal.valor / c.comprado * 100, 0)} de lo comprado'
              : 'Lo comprado por proveedor',
          cargando: b.cargando,
          error: b.error,
          vacio: c == null || c.porProveedor.isEmpty,
          alto: 200,
          contenido: () => GraficoBarrasH(
            formato: (n) => moneda(n),
            unColor: PaletaDash.serie[4],
            items: [
              for (final i in c!.porProveedor)
                ItemBarraH(
                  nombre: i.nombre,
                  valor: i.valor,
                  detalle: compras(i.cantidad),
                ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Qué se compra',
          subtitulo: 'Por categoría',
          cargando: b.cargando,
          error: b.error,
          vacio: c == null || c.porCategoria.isEmpty,
          alto: 180,
          contenido: () => GraficoDona(
            formato: compacto,
            centro: (titulo: 'Comprado', valor: moneda(c!.comprado)),
            porciones: [
              for (final i in c.porCategoria)
                PorcionDona(
                  nombre: i.nombre,
                  valor: i.valor,
                  color: i.nombre.startsWith('Sin ') ? PaletaDash.neutro : null,
                ),
            ],
          ),
        ),

        MarcoGrafico(
          titulo: 'Cómo cambian los costos',
          subtitulo: c == null
              ? null
              : cambios.isEmpty
              ? 'La última compra de cada producto frente a la anterior'
              : '${cambios.join(', ')} frente a su compra anterior',
          cargando: b.cargando,
          error: b.error,
          vacio: costos.isEmpty,
          mensajeVacio: 'Sin cambios de costo en el período',
          alto: 240,
          contenido: () => _ListaCostos(costos: costos),
        ),
      ],
    );
  }
}

/// Los productos cuyo costo más cambió. Una lista y no barras: lo que importa
/// es el antes y el ahora, y si subió o bajó, que el largo de una barra no
/// dice.
class _ListaCostos extends StatelessWidget {
  const _ListaCostos({required this.costos});

  final List<DashCostoProducto> costos;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < costos.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: Colores.linea),
          _FilaCosto(costo: costos[i]),
        ],
      ],
    );
  }
}

class _FilaCosto extends StatelessWidget {
  const _FilaCosto({required this.costo});

  final DashCostoProducto costo;

  @override
  Widget build(BuildContext context) {
    final unidad = costo.unidad.isEmpty ? 'unidad' : costo.unidad.toLowerCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimen.espacio2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dos renglones antes de cortar: los nombres de producto son
                // largos y aquí no hay globo que muestre el resto.
                Text(
                  costo.producto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colores.tinta,
                  ),
                ),
                const SizedBox(height: 2),
                // Con céntimos: es el costo de una unidad base, de pocos
                // soles, y sin ellos S/ 2.40 → S/ 2.60 se leería S/ 2 → S/ 3.
                Text(
                  '${moneda(costo.costoAnterior, 2)} → '
                  '${moneda(costo.costoActual, 2)} por $unidad',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colores.tintaSuave,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Dimen.espacio3),
          _ChipVariacion(variacion: costo.variacion),
        ],
      ),
    );
  }
}

/// Cuánto cambió el costo. Al revés que en las ventas: que el costo suba es
/// malo (rojo) y que baje es bueno (verde). Los mismos tonos que el chip de
/// cambio de [TarjetaKpi].
class _ChipVariacion extends StatelessWidget {
  const _ChipVariacion({required this.variacion});

  final double variacion;

  @override
  Widget build(BuildContext context) {
    final sube = variacion > 0;
    final baja = variacion < 0;
    final signo = sube
        ? '+'
        : baja
        ? '−'
        : '';
    final (fondo, texto) = sube
        ? (Colores.peligroSuave, const Color(0xFFB91C1C))
        : baja
        ? (Colores.exitoSuave, const Color(0xFF047857))
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
                ? Icons.trending_up
                : baja
                ? Icons.trending_down
                : Icons.remove,
            size: 12,
            color: texto,
          ),
          const SizedBox(width: 2),
          Text(
            '$signo${porcentaje(variacion.abs())}',
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
