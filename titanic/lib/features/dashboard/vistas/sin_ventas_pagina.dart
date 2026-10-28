import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_pestanas.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../crm/datos/crm.dart';
import '../../crm/estado/crm_controlador.dart';
import '../../crm/vistas/crm_comun.dart';

/// Productos sin ventas: lo que está en el catálogo y no se vendió en los
/// últimos días. Los que tienen stock son plata parada; los que no, un producto
/// que ni se compra ni se vende.
class SinVentasPagina extends ConsumerWidget {
  const SinVentasPagina({super.key});

  static const ruta = '/dashboard/sinventas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final estado = ref.watch(sinVentasProvider);
    final d = estado.valueOrNull;
    final dias = ref.watch(diasSinVentasProvider);
    final stock = ref.watch(stockSinVentasFiltroProvider);

    return AppListaPagina<ProductoSinVenta>(
      titulo: 'Productos sin ventas',
      ruta: ruta,
      estado: estado.whenData((r) => r.items),
      visibles: ref.watch(sinVentasFiltradasProvider),
      busqueda: ref.watch(busquedaSinVentasProvider),
      onBuscar: (t) => ref.read(busquedaSinVentasProvider.notifier).state = t,
      pistaBusqueda: 'Buscar producto, código o categoría',
      onRecargar: () async {
        ref.invalidate(sinVentasProvider);
        try {
          await ref.read(sinVentasProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      iconoVacio: Icons.inventory_2_outlined,
      singular: 'producto',
      plural: 'productos',
      tituloVacio: 'Todo se vendió',
      detalleVacio: 'Todos los productos se vendieron en este período.',
      pestanas: AppPestanas<int>(
        activa: dias,
        onCambio: (v) => ref.read(diasSinVentasProvider.notifier).state = v,
        pestanas: [for (final n in diasSinVentas) Pestana<int>(n, '$n días')],
      ),
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Sin ventas',
          valor: '${d?.sinVentas ?? 0}',
          icono: Icons.inventory_2_outlined,
          tono: DatoTono.aviso,
          nota: 'de ${d?.productosActivos ?? 0} productos activos',
        ),
        AppTarjetaDato(
          etiqueta: 'Con stock',
          valor: '${d?.conStock ?? 0}',
          icono: Icons.warehouse_outlined,
          tono: DatoTono.neutral,
          nota: '${d?.sinStock ?? 0} sin stock',
        ),
        AppTarjetaDato(
          etiqueta: 'Plata parada',
          valor: soles(d?.capitalParado ?? 0),
          icono: Icons.savings_outlined,
          tono: DatoTono.peligro,
          nota: 'stock a costo',
        ),
        AppTarjetaDato(
          etiqueta: 'Nunca vendidos',
          valor: '${d?.nuncaVendidos ?? 0}',
          icono: Icons.search_off,
          tono: DatoTono.neutral,
        ),
      ],
      encabezado: d == null
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
              child: Text(
                'Sin ventas del ${fechaDia(d.rango.desde)} al '
                '${fechaDia(d.rango.hasta)}. El stock suma todos los almacenes '
                'y se valoriza a su costo.',
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
      filtro: BotonFiltros(
        activos: stock == null ? 0 : 1,
        color: color,
        onAbrir: () => mostrarFiltros(
          context,
          activos: ref.read(stockSinVentasFiltroProvider) == null ? 0 : 1,
          onLimpiar: () =>
              ref.read(stockSinVentasFiltroProvider.notifier).state = null,
          grupos: [
            Consumer(
              builder: (context, ref, _) => GrupoFiltro<String?>(
                titulo: 'Stock',
                valor: ref.watch(stockSinVentasFiltroProvider),
                opciones: const [
                  OpcionFiltro(null, 'Todos'),
                  OpcionFiltro('con', 'Con stock'),
                  OpcionFiltro('sin', 'Sin stock'),
                ],
                onCambio: (v) =>
                    ref.read(stockSinVentasFiltroProvider.notifier).state = v,
              ),
            ),
          ],
        ),
      ),
      fila: (context, p) => AppTarjetaRegistro(
        icono: Icons.inventory_2_outlined,
        color: color,
        titulo: p.producto,
        insignia: AppEtiqueta(p.codigo),
        campos: [
          CampoDetalle(
            'Categoría',
            [p.categoria, p.marca].whereType<String>().join(' · '),
          ),
          CampoDetalle(
            'En stock',
            p.stock > 0
                ? '${p.stock.toStringAsFixed(p.stock % 1 == 0 ? 0 : 2)} ${p.unidadBase}'
                : 'Sin stock',
          ),
          CampoDetalle(
            'Plata parada',
            null,
            widget: Text(
              p.valorStock > 0 ? soles(p.valorStock) : '—',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.valorStock > 0 ? Colores.peligro : Colores.tintaTenue,
              ),
            ),
          ),
          CampoDetalle(
            'Última venta',
            p.ultimaVenta == null
                ? 'Nunca'
                : '${fechaDia(p.ultimaVenta)} · hace ${p.diasSinVender} días',
          ),
        ],
      ),
    );
  }
}
