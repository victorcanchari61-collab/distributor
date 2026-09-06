import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/colores.dart';
import '../../ventas/datos/cobro.dart';
import '../../ventas/estado/ventas_controlador.dart';

/// Historial de pagos de notas de venta, aplanado: incluye los anulados.
class MisCobrosPagina extends ConsumerWidget {
  const MisCobrosPagina({super.key});

  static const ruta = '/finanzas/miscobros';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos = ref.watch(misCobrosProvider).valueOrNull ?? const <Cobro>[];
    final validos = todos.where((c) => !c.anulado).toList();
    final anulados = todos.where((c) => c.anulado).length;
    final totalCobrado = validos.fold<double>(0, (n, c) => n + c.monto);

    return AppListaPagina<Cobro>(
      titulo: 'Mis cobros',
      ruta: ruta,
      estado: ref.watch(misCobrosProvider),
      visibles: ref.watch(misCobrosFiltradosProvider),
      busqueda: ref.watch(busquedaMisCobrosProvider),
      onBuscar: (t) => ref.read(busquedaMisCobrosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número o cliente',
      onRecargar: () => ref.read(misCobrosProvider.notifier).recargar(),
      iconoVacio: Icons.savings_outlined,
      singular: 'cobro',
      plural: 'cobros',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Cobros válidos',
          valor: '${validos.length}',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Total cobrado',
          valor: 'S/ ${totalCobrado.toStringAsFixed(2)}',
          icono: Icons.savings_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Cobros anulados',
          valor: '$anulados',
          icono: Icons.block,
          tono: anulados > 0 ? DatoTono.aviso : DatoTono.neutral,
        ),
      ],
      fila: (context, cobro) => _TarjetaCobro(cobro: cobro, color: color),
    );
  }
}

class _TarjetaCobro extends StatelessWidget {
  const _TarjetaCobro({required this.cobro, required this.color});

  final Cobro cobro;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.savings_outlined,
      color: color,
      titulo: cobro.notaVentaNumero,
      insignia: AppEtiqueta(
        cobro.anulado ? 'Anulado' : 'Válido',
        tono: cobro.anulado ? EtiquetaTono.peligro : EtiquetaTono.exito,
      ),
      campos: [
        CampoDetalle('Cliente', cobro.cliente),
        CampoDetalle('Fecha', _fecha(cobro.fecha)),
        CampoDetalle('Método', cobro.metodoPago),
        CampoDetalle(
          'Monto',
          'S/ ${cobro.monto.toStringAsFixed(2)}',
          widget: Text(
            'S/ ${cobro.monto.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cobro.anulado ? Colores.tintaTenue : Colores.tinta,
              decoration: cobro.anulado ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
