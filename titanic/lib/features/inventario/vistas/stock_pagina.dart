import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/colores.dart';
import '../datos/stock.dart';
import '../estado/inventario_controlador.dart';
import 'almacen_tabs.dart';

/// Cuánto hay y a qué costo, por almacén.
///
/// Es solo consulta: aquí no se mueve stock. Para eso está Ajustes de
/// inventario, el único documento que crea movimientos manuales.
class StockPagina extends ConsumerWidget {
  const StockPagina({super.key});

  static const ruta = '/inv/stock';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos = ref.watch(stockProvider).valueOrNull ?? const <Stock>[];
    final almacenes = ref.watch(almacenesActivosProvider);
    final almacenId = ref.watch(almacenStockProvider);

    final conStock = todos.where((s) => s.stock > 0).length;
    final bajoMinimo = todos.where((s) => s.bajoMinimo).length;
    final valorTotal = todos.fold<double>(0, (n, s) => n + s.valorizado);

    return AppListaPagina<Stock>(
      titulo: 'Stock por almacén',
      ruta: ruta,
      estado: ref.watch(stockProvider),
      visibles: ref.watch(stockFiltradoProvider),
      busqueda: ref.watch(busquedaStockProvider),
      onBuscar: (t) => ref.read(busquedaStockProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por código, producto o categoría',
      onRecargar: () async {
        ref.invalidate(stockProvider);
        await ref.read(stockProvider.future);
      },
      iconoVacio: Icons.inventory_outlined,
      singular: 'producto con stock',
      plural: 'productos con stock',
      tituloVacio: 'Sin stock',
      detalleVacio: 'No hay productos que controlen stock aquí.',
      encabezado: AlmacenTabs(
        almacenes: almacenes,
        valor: almacenId,
        color: color,
        onCambio: (v) => ref.read(almacenStockProvider.notifier).state = v,
      ),
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Con stock',
          valor: '$conStock',
          icono: Icons.inventory_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Bajo el mínimo',
          valor: '$bajoMinimo',
          icono: Icons.warning_amber_outlined,
          tono: bajoMinimo > 0 ? DatoTono.aviso : DatoTono.neutral,
          nota: bajoMinimo > 0 ? 'reponer pronto' : 'todo en orden',
        ),
        AppTarjetaDato(
          etiqueta: 'Valor del inventario',
          valor: 'S/ ${valorTotal.toStringAsFixed(2)}',
          icono: Icons.payments_outlined,
          tono: DatoTono.exito,
          nota: 'al costo de compra',
        ),
      ],
      fila: (context, stock) => _TarjetaStock(stock: stock, color: color),
    );
  }
}

class _TarjetaStock extends StatelessWidget {
  const _TarjetaStock({required this.stock, required this.color});

  final Stock stock;
  final Color color;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Categoría', stock.categoria, enTarjeta: false),
    CampoDetalle('Marca', stock.marca, enTarjeta: false),
    CampoDetalle('Almacén', stock.almacen),
    CampoDetalle(
      'Stock',
      '${formatoNumero(stock.stock)} ${stock.unidadBase}',
      widget: !stock.bajoMinimo
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  size: 13,
                  color: Colores.advertencia,
                ),
                const SizedBox(width: 3),
                Text(
                  '${formatoNumero(stock.stock)} ${stock.unidadBase}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colores.advertencia,
                  ),
                ),
              ],
            ),
    ),
    CampoDetalle(
      'Costo actual',
      stock.costoActual == null ? null : 'S/ ${stock.costoActual!.toStringAsFixed(2)}',
    ),
    CampoDetalle('Valorizado', 'S/ ${stock.valorizado.toStringAsFixed(2)}'),
    CampoDetalle(
      'Capas de costo',
      stock.capas.isEmpty
          ? null
          : stock.capas.length == 1
          ? '1 capa'
          : '${stock.capas.length} capas',
      enTarjeta: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.inventory_outlined,
      color: color,
      titulo: stock.producto,
      insignia: AppEtiqueta(stock.codigo),
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: Icons.inventory_outlined,
        color: color,
        titulo: stock.producto,
        subtitulo: stock.codigo,
        campos: _campos,
      ),
    );
  }
}
