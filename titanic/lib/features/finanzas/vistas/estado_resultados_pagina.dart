import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../dashboard/widgets/tablero_pagina.dart';
import '../../dashboard/widgets/tarjeta_kpi.dart';
import '../datos/tesoreria.dart';
import '../estado/tesoreria_controlador.dart';
import 'hojas_finanzas.dart';

String _pct(double? n) => n == null ? '—' : '${n.toStringAsFixed(1)}%';

/// Si el negocio gana, en un rango de fechas.
///
/// Arriba lo vendido menos lo que costo (la utilidad bruta, la misma de Mis
/// ganancias), despues los demas ingresos y gastos de operar y la utilidad
/// operativa. Lo no operativo —prestamos, aportes, retiros— va aparte, solo
/// para mirar. Es un reporte de gestion, no tributario. Igual que el panel web.
class EstadoResultadosPagina extends ConsumerWidget {
  const EstadoResultadosPagina({super.key});

  static const ruta = '/finanzas/resultados';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoResultadosProvider);
    final e = estado.valueOrNull;

    return TableroPagina(
      ruta: ruta,
      descripcion:
          'Si el negocio gana: lo vendido sin IGV, menos lo que costó, menos '
          'los gastos de operar. Préstamos, aportes y retiros van aparte y no suman.',
      periodo: ref.watch(periodoResultadosProvider),
      onPeriodo: (p) => ref.read(periodoResultadosProvider.notifier).state = p,
      onRecargar: () async {
        ref.invalidate(estadoResultadosProvider);
        try {
          await ref.read(estadoResultadosProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla.
        }
      },
      hijos: [
        if (estado.hasError)
          AppAlerta(
            estado.error is ApiExcepcion
                ? (estado.error as ApiExcepcion).texto
                : 'No pudimos calcular el estado de resultados.',
          ),
        FilaKpi(
          cargando: estado.isLoading && e == null,
          tarjetas: [
            if (e != null) ...[
              TarjetaKpi(
                titulo: 'Ventas netas',
                valor: formatoSoles(e.ventasNetas),
                icono: Icons.receipt_long_outlined,
                nota:
                    '${e.ventas} ${e.ventas == 1 ? 'venta' : 'ventas'}, sin IGV',
              ),
              TarjetaKpi(
                titulo: 'Utilidad bruta',
                valor: formatoSoles(e.utilidadBruta),
                icono: Icons.trending_up,
                color: e.utilidadBruta < 0 ? Colores.peligro : Colores.exito,
                nota: 'Margen ${_pct(e.margenBruto)}',
              ),
              TarjetaKpi(
                titulo: 'Gastos operativos',
                valor: formatoSoles(e.totalGastosOperativos),
                icono: Icons.trending_down,
                color: Colores.advertencia,
                nota: 'Otros ingresos ${formatoSoles(e.totalOtrosIngresos)}',
              ),
              TarjetaKpi(
                titulo: 'Utilidad operativa',
                valor: formatoSoles(e.utilidadOperativa),
                icono: Icons.calculate_outlined,
                color: e.utilidadOperativa < 0
                    ? Colores.peligro
                    : Colores.exito,
                nota: 'Margen ${_pct(e.margenOperativo)}',
              ),
            ],
          ],
        ),
        if (e != null && e.lineasSinCosto > 0)
          AppAlerta(
            '${e.lineasSinCosto} ${e.lineasSinCosto == 1 ? 'línea vendida no tiene costo' : 'líneas vendidas no tienen costo'}: '
            'ahí el costo sale en cero y la utilidad queda inflada.',
            tono: AlertaTono.aviso,
          ),
        if (e != null) ...[
          _Panel(
            titulo: 'Del ${fechaCorta(e.desde)} al ${fechaCorta(e.hasta)}',
            hijos: [
              _Renglon('Ventas (con IGV)', e.ventasBrutas),
              _Renglon('(−) IGV', -e.igv, tenue: true),
              _Renglon('Ventas netas', e.ventasNetas, fuerte: true),
              _Renglon('(−) Costo de lo vendido', -e.costoVentas),
              _Total('Utilidad bruta', e.utilidadBruta, e.margenBruto),
              ..._bloque(
                '(+) Otros ingresos operativos',
                e.totalOtrosIngresos,
                e.otrosIngresos,
                1,
              ),
              ..._bloque(
                '(−) Gastos operativos',
                e.totalGastosOperativos,
                e.gastosOperativos,
                -1,
              ),
              _Total(
                'Utilidad operativa',
                e.utilidadOperativa,
                e.margenOperativo,
              ),
            ],
          ),
          _Panel(
            titulo: 'No operativo',
            apoyo:
                'Préstamos, aportes, retiros y activos: mueven plata, pero no son '
                'ganancia ni gasto del negocio. No suman a la utilidad.',
            hijos: [
              ..._bloque(
                '(+) Ingresos',
                e.totalIngresosNoOperativos,
                e.ingresosNoOperativos,
                1,
              ),
              ..._bloque(
                '(−) Egresos',
                e.totalEgresosNoOperativos,
                e.egresosNoOperativos,
                -1,
              ),
              _Renglon(
                'Neto no operativo',
                e.totalIngresosNoOperativos - e.totalEgresosNoOperativos,
                fuerte: true,
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Un grupo de categorias: su total y cada una debajo.
  List<Widget> _bloque(
    String titulo,
    double total,
    List<LineaResultado> lineas,
    int signo,
  ) => [
    _Renglon(titulo, signo * total, fuerte: true),
    if (lineas.isEmpty)
      const Padding(
        padding: EdgeInsets.fromLTRB(
          Dimen.espacio5,
          0,
          Dimen.espacio3,
          Dimen.espacio2,
        ),
        child: Text(
          'Nada en este rango.',
          style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
        ),
      )
    else
      for (final l in lineas)
        _Renglon(
          l.concepto,
          signo * l.monto,
          tenue: true,
          sangria: true,
          detalle: '${l.movimientos} ${l.movimientos == 1 ? 'mov.' : 'movs.'}',
        ),
  ];
}

/// Un recuadro del estado, con su titulo.
class _Panel extends StatelessWidget {
  const _Panel({required this.titulo, required this.hijos, this.apoyo});

  final String titulo;
  final String? apoyo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: Dimen.espacio4),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioPanel),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(Dimen.espacio3),
            child: Text(
              titulo,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          if (apoyo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimen.espacio3,
                0,
                Dimen.espacio3,
                Dimen.espacio2,
              ),
              child: Text(
                apoyo!,
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
          const Divider(height: 1),
          ...hijos,
        ],
      ),
    );
  }
}

/// Un renglon con su monto a la derecha; los negativos en rojo.
class _Renglon extends StatelessWidget {
  const _Renglon(
    this.concepto,
    this.monto, {
    this.fuerte = false,
    this.tenue = false,
    this.sangria = false,
    this.detalle,
  });

  final String concepto;
  final double monto;
  final bool fuerte;
  final bool tenue;
  final bool sangria;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        sangria ? Dimen.espacio5 : Dimen.espacio3,
        Dimen.espacio2,
        Dimen.espacio3,
        Dimen.espacio2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: concepto,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: fuerte ? FontWeight.w700 : FontWeight.w400,
                  color: tenue ? Colores.tintaSuave : Colores.tinta,
                ),
                children: [
                  if (detalle != null)
                    TextSpan(
                      text: '  $detalle',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colores.tintaTenue,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Dimen.espacio2),
          Text(
            formatoSoles(monto),
            style: TextStyle(
              fontSize: 13,
              fontWeight: fuerte ? FontWeight.w700 : FontWeight.w400,
              color: monto < 0
                  ? Colores.peligro
                  : tenue
                  ? Colores.tintaSuave
                  : Colores.tinta,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una utilidad: el renglon que resume lo de arriba, con su margen.
class _Total extends StatelessWidget {
  const _Total(this.concepto, this.monto, this.margen);

  final String concepto;
  final double monto;
  final double? margen;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colores.fondo,
      padding: const EdgeInsets.all(Dimen.espacio3),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: concepto.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
                children: [
                  TextSpan(
                    text: '  margen ${_pct(margen)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      color: Colores.tintaSuave,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            formatoSoles(monto),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: monto < 0 ? Colores.peligro : Colores.exito,
            ),
          ),
        ],
      ),
    );
  }
}
