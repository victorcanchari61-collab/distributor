import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_filtros.dart';
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
      filtro: BotonFiltros(
        activos: ref.watch(filtrosStockActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, stock) => _TarjetaStock(stock: stock, color: color),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosStockActivosProvider),
      onLimpiar: () {
        ref.read(filtroStockProvider.notifier).state = FiltroStock.todos;
        ref.read(categoriaStockProvider.notifier).state = null;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroStock>(
            titulo: 'Situación',
            valor: ref.watch(filtroStockProvider),
            opciones: const [
              OpcionFiltro(FiltroStock.todos, 'Todos'),
              OpcionFiltro(FiltroStock.bajoMinimo, 'Bajo el mínimo'),
              OpcionFiltro(FiltroStock.sinStock, 'Sin stock'),
              OpcionFiltro(FiltroStock.conStock, 'Con stock'),
            ],
            onCambio: (v) => ref.read(filtroStockProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Categoría',
            valor: ref.watch(categoriaStockProvider),
            opciones: [
              const OpcionFiltro<String?>(null, 'Todas'),
              for (final c in ref.watch(categoriasDelStockProvider))
                OpcionFiltro<String?>(c, c),
            ],
            onCambio: (v) =>
                ref.read(categoriaStockProvider.notifier).state = v,
          ),
        ),
      ],
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
    if (stock.reservado > 0) ...[
      CampoDetalle('Reservado', '${formatoNumero(stock.reservado)} ${stock.unidadBase}'),
      CampoDetalle('Disponible', '${formatoNumero(stock.disponible)} ${stock.unidadBase}'),
    ],
    // Cuanto pedir. El triangulo ambar avisa que falta, pero no cuanto, que es
    // lo que se necesita para armar la compra.
    if (stock.faltaReponer > 0)
      CampoDetalle(
        'Falta reponer',
        '${formatoNumero(stock.faltaReponer)} ${stock.unidadBase}',
        widget: Text(
          '${formatoNumero(stock.faltaReponer)} ${stock.unidadBase}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colores.advertencia,
          ),
        ),
      ),

    // Lo comprado que no ha llegado: sin esto se vuelve a comprar lo que ya
    // viene en camino, que es como el almacen termina con el doble.
    if (stock.enTransito > 0)
      CampoDetalle(
        'En camino',
        '${formatoNumero(stock.enTransito)} ${stock.unidadBase}',
      ),

    // Para cuantos dias alcanza al ritmo de venta del ultimo mes.
    if (stock.diasStock != null)
      CampoDetalle(
        'Días de stock',
        '${stock.diasStock} d',
        widget: Text(
          '${stock.diasStock} d',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: stock.diasStock! <= 7
                ? Colores.peligro
                : stock.diasStock! <= 15
                ? Colores.advertencia
                : Colores.tintaSuave,
          ),
        ),
      ),

    CampoDetalle(
      'Costo actual',
      stock.costoActual == null ? null : 'S/ ${stock.costoActual!.toStringAsFixed(2)}',
    ),
    CampoDetalle('Valorizado', 'S/ ${stock.valorizado.toStringAsFixed(2)}'),

    // Lo que no rota: 200 kilos sin moverse desde julio es plata parada.
    CampoDetalle(
      'Última salida',
      stock.ultimaSalida == null ? 'Nunca' : _fecha(stock.ultimaSalida!),
      enTarjeta: false,
    ),
    CampoDetalle(
      'Última entrada',
      stock.ultimaEntrada == null ? 'Nunca' : _fecha(stock.ultimaEntrada!),
      enTarjeta: false,
    ),
  ];

  List<Widget> get _capas => [
    for (var i = 0; i < stock.capas.length; i++)
      LineaProductoTarjeta(
        titulo: i == 0 ? 'Capa ${i + 1} (la que se consume ahora)' : 'Capa ${i + 1}',
        subtitulo: _fecha(stock.capas[i].fecha),
        filas: [
          [
            ('Disponible', '${formatoNumero(stock.capas[i].cantidadDisponible)} ${stock.unidadBase}'),
            ('Costo unit.', 'S/ ${stock.capas[i].costoUnitario.toStringAsFixed(2)}'),
            ('Valor', 'S/ ${stock.capas[i].valor.toStringAsFixed(2)}'),
          ],
        ],
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
        contenidoExtra: _capas,
      ),
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
