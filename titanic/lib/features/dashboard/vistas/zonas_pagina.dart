import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_pestanas.dart';
import '../../../compartido/widgets/app_selector_rango.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../crm/datos/crm.dart';
import '../../crm/estado/crm_controlador.dart';
import '../../crm/vistas/crm_comun.dart';

/// Mercados y rutas: la misma caída de ventas de los clientes, pero juntándolos
/// por zona. Sirve para ver si el problema es de un cliente o de toda una
/// zona: un mercado donde bajan varios a la vez no se arregla llamando de a uno.
class ZonasPagina extends ConsumerWidget {
  const ZonasPagina({super.key});

  static const ruta = '/dashboard/zonas';

  /// Cuántos clientes de la zona están en cada estado de caída.
  static String _enCaida(ZonaCaida z) {
    final partes = [
      if (z.criticos > 0) '${z.criticos} críticos',
      if (z.enRiesgo > 0) '${z.enRiesgo} en riesgo',
      if (z.enSeguimiento > 0) '${z.enSeguimiento} en seguimiento',
    ];
    return partes.isEmpty ? '—' : partes.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final estado = ref.watch(zonasProvider);
    final d = estado.valueOrNull;
    final agrupar = ref.watch(agruparZonasProvider);
    final singular = agrupar == 'mercado' ? 'mercado' : 'ruta';

    final items = d?.items ?? const <ZonaCaida>[];
    final perdida = items.fold<double>(0, (s, z) => s + z.ventaPerdida);
    final enRiesgo = items.fold<int>(0, (s, z) => s + z.criticos + z.enRiesgo);
    final actual = items.fold<double>(0, (s, z) => s + z.ventaActual);
    final anterior = items.fold<double>(0, (s, z) => s + z.ventaAnterior);
    final peor = items.where((z) => z.ventaPerdida > 0).firstOrNull;

    return AppListaPagina<ZonaCaida>(
      titulo: 'Mercados y rutas',
      ruta: ruta,
      estado: estado.whenData((r) => r.items),
      visibles: ref.watch(zonasFiltradasProvider),
      busqueda: ref.watch(busquedaZonasProvider),
      onBuscar: (t) => ref.read(busquedaZonasProvider.notifier).state = t,
      pistaBusqueda: 'Buscar $singular',
      onRecargar: () async {
        ref.invalidate(zonasProvider);
        try {
          await ref.read(zonasProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      iconoVacio: Icons.storefront_outlined,
      singular: singular,
      plural: agrupar == 'mercado' ? 'mercados' : 'rutas',
      tituloVacio: 'Sin ventas',
      detalleVacio: 'No hay clientes con ventas en este tramo.',
      pestanas: AppPestanas<String>(
        activa: agrupar,
        onCambio: (v) => ref.read(agruparZonasProvider.notifier).state = v,
        pestanas: const [
          Pestana<String>(
            'mercado',
            'Por mercado',
            icono: Icons.storefront_outlined,
          ),
          Pestana<String>('ruta', 'Por ruta', icono: Icons.route_outlined),
        ],
      ),
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Venta perdida',
          valor: soles(perdida),
          icono: Icons.trending_down,
          tono: DatoTono.aviso,
          nota: peor == null ? 'ninguna bajó' : 'la mayor, en ${peor.nombre}',
        ),
        AppTarjetaDato(
          etiqueta: 'Clientes en riesgo',
          valor: '$enRiesgo',
          icono: Icons.warning_amber_rounded,
          tono: DatoTono.peligro,
          nota: 'críticos y en riesgo',
        ),
        AppTarjetaDato(
          etiqueta: 'Vendido',
          valor: soles(actual),
          icono: Icons.payments_outlined,
          color: color,
          nota: 'antes ${soles(anterior)}',
        ),
      ],
      encabezado: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
            child: AppSelectorRango(
              rango: ref.watch(rangoZonasProvider),
              textoVacio: 'Del 1 de enero a hoy',
              onCambio: (r) => ref.read(rangoZonasProvider.notifier).state = r,
            ),
          ),
          if (d != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimen.espacio4,
                Dimen.espacio2,
                Dimen.espacio4,
                0,
              ),
              child: Text(
                'Del ${d.periodo.etiqueta} frente al ${d.periodo.etiquetaAnterior}.',
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
          if (d != null && d.soloPropios)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                Dimen.espacio4,
                Dimen.espacio2,
                Dimen.espacio4,
                0,
              ),
              child: AppAlerta(
                'Ves solo los clientes de tus rutas y los que tienes asignados.',
                tono: AlertaTono.aviso,
              ),
            ),
        ],
      ),
      fila: (context, z) => AppTarjetaRegistro(
        icono: agrupar == 'mercado'
            ? Icons.storefront_outlined
            : Icons.route_outlined,
        color: color,
        titulo: z.nombre,
        campos: [
          CampoDetalle('Clientes', '${z.clientes} · ${z.conVentas} compraron'),
          CampoDetalle(
            'En caída',
            null,
            widget: Text(
              _enCaida(z),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: z.criticos > 0 ? Colores.peligro : Colores.tinta,
              ),
            ),
          ),
          CampoDetalle(
            'Venta',
            '${soles(z.ventaActual)} (antes ${soles(z.ventaAnterior)})',
          ),
          CampoDetalle(
            'Variación',
            null,
            widget: Text(
              '${solesConSigno(z.variacion)}  ·  '
              '${z.caidaPct == null ? 'Sin comparación' : porcentaje(-z.caidaPct!)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorCambio(z.variacion),
              ),
            ),
          ),
          if (z.ventaPerdida > 0)
            CampoDetalle(
              'Venta perdida',
              null,
              widget: Text(
                soles(z.ventaPerdida),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colores.peligro,
                ),
              ),
            ),
          if (z.saldoPorCobrar > 0)
            CampoDetalle('Debe', soles(z.saldoPorCobrar)),
        ],
      ),
    );
  }
}
