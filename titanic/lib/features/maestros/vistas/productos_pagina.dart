import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/catalogo.dart';
import '../datos/producto.dart';
import '../estado/maestros_controlador.dart';
import 'producto_formulario.dart';

/// Listado de productos.
class ProductosPagina extends ConsumerWidget {
  const ProductosPagina({super.key});

  static const ruta = '/maestros/productos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos = ref.watch(productosProvider).valueOrNull ?? const <Producto>[];
    final activos = todos.where((p) => p.activo).toList();
    final categorias =
        ref.watch(categoriasProvider).valueOrNull ?? const <Categoria>[];
    final marcas = ref.watch(marcasProvider).valueOrNull ?? const <Marca>[];
    final puestos = ref.watch(filtrosProductosActivosProvider);
    final totalPresentaciones = activos.fold<int>(
      0,
      (n, p) => n + p.presentaciones.length,
    );

    return AppListaPagina<Producto>(
      titulo: 'Productos',
      ruta: ruta,
      estado: ref.watch(productosProvider),
      visibles: ref.watch(productosFiltradosProvider),
      busqueda: ref.watch(busquedaProductosProvider),
      onBuscar: (t) => ref.read(busquedaProductosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por nombre, código o categoría',
      onRecargar: () => ref.read(productosProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      iconoVacio: Icons.inventory_2_outlined,
      singular: 'producto',
      plural: 'productos',
      detalleVacio: puestos > 0
          ? 'Ninguno coincide con los filtros puestos.'
          : null,
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Productos activos',
          valor: '${activos.length}',
          icono: Icons.inventory_2_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Desactivados',
          valor: '${todos.length - activos.length}',
          icono: Icons.block,
          tono: todos.length == activos.length
              ? DatoTono.neutral
              : DatoTono.aviso,
          nota: 'no salen en operaciones',
        ),
        AppTarjetaDato(
          etiqueta: 'Categorías',
          valor: '${categorias.length}',
          icono: Icons.category_outlined,
          tono: DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'Presentaciones',
          valor: '$totalPresentaciones',
          icono: Icons.widgets_outlined,
          tono: DatoTono.exito,
          nota: 'formas de vender',
        ),
      ],
      filtro: BotonFiltros(
        activos: puestos,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref, categorias, marcas),
      ),
      fila: (context, producto) => _TarjetaProducto(
        producto: producto,
        color: color,
        onEditar: () => _abrirFormulario(context, producto),
        onEstado: () => _cambiarEstado(context, ref, producto),
      ),
    );
  }

  Future<void> _abrirFiltros(
    BuildContext context,
    WidgetRef ref,
    List<Categoria> categorias,
    List<Marca> marcas,
  ) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosProductosActivosProvider),
      onLimpiar: () {
        ref.read(estadoFiltroProvider.notifier).state = FiltroEstado.activos;
        ref.read(categoriaFiltroProvider.notifier).state = null;
        ref.read(marcaFiltroProvider.notifier).state = null;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroEstado>(
            titulo: 'Estado',
            valor: ref.watch(estadoFiltroProvider),
            opciones: const [
              OpcionFiltro(FiltroEstado.activos, 'Activos'),
              OpcionFiltro(FiltroEstado.inactivos, 'Desactivados'),
              OpcionFiltro(FiltroEstado.todos, 'Todos'),
            ],
            onCambio: (v) => ref.read(estadoFiltroProvider.notifier).state = v,
          ),
        ),
        if (categorias.isNotEmpty)
          Consumer(
            builder: (context, ref, _) => GrupoFiltro<int?>(
              titulo: 'Categoría',
              valor: ref.watch(categoriaFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todas'),
                for (final c in categorias) OpcionFiltro(c.id, c.nombre),
              ],
              onCambio: (v) =>
                  ref.read(categoriaFiltroProvider.notifier).state = v,
            ),
          ),
        if (marcas.isNotEmpty)
          Consumer(
            builder: (context, ref, _) => GrupoFiltro<int?>(
              titulo: 'Marca',
              valor: ref.watch(marcaFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todas'),
                for (final m in marcas) OpcionFiltro(m.id, m.nombre),
              ],
              onCambio: (v) => ref.read(marcaFiltroProvider.notifier).state = v,
            ),
          ),
      ],
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Producto? producto) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductoFormulario(producto: producto)),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    Producto producto,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: '${producto.activo ? 'Desactivar' : 'Activar'} ${producto.nombre}',
      mensaje: producto.activo
          ? 'Deja de aparecer para nuevas operaciones, pero conserva su historial y puedes volver a activarlo.'
          : 'Vuelve a estar disponible para usarse.',
      textoConfirmar: producto.activo ? 'Desactivar' : 'Activar',
      tono: producto.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref.read(productosProvider.notifier).cambiarEstado(producto);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            producto.activo
                ? '${producto.nombre} desactivado'
                : '${producto.nombre} activado',
          ),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaProducto extends StatelessWidget {
  const _TarjetaProducto({
    required this.producto,
    required this.color,
    required this.onEditar,
    required this.onEstado,
  });

  final Producto producto;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEstado;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Marca', producto.marca),
    CampoDetalle('Categoría', producto.categoria, enTarjeta: false),
    CampoDetalle('Unidad base', producto.unidadBase),
    CampoDetalle(
      'Costo referencia',
      producto.costoReferencia == null
          ? null
          : 'S/ ${producto.costoReferencia!.toStringAsFixed(2)}',
    ),
    CampoDetalle(
      'Presentaciones',
      producto.presentaciones.length == 1
          ? '1 presentación'
          : '${producto.presentaciones.length} presentaciones',
      enTarjeta: false,
    ),
    CampoDetalle(
      'Control de stock',
      producto.controlaStock
          ? 'Sí · mínimo ${formatoNumero(producto.stockMinimo)} ${producto.unidadBase}'
          : 'No',
      enTarjeta: false,
    ),
    CampoDetalle(
      'Estado',
      producto.activo ? 'Activo' : 'Inactivo',
      widget: AppEtiqueta(
        producto.activo ? 'Activo' : 'Inactivo',
        tono: producto.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.inventory_2_outlined,
      color: color,
      titulo: producto.nombre,
      insignia: AppEtiqueta(producto.codigo),
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.edit_outlined, size: 18, color: Acento.de(context)),
        ),
        IconButton(
          onPressed: onEstado,
          tooltip: producto.activo ? 'Desactivar' : 'Activar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            producto.activo ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: producto.activo ? Colores.advertencia : Colores.exito,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.inventory_2_outlined,
      color: color,
      titulo: producto.nombre,
      subtitulo: producto.codigo,
      insignia: producto.activo
          ? null
          : const AppEtiqueta('Inactivo', tono: EtiquetaTono.aviso),
      campos: _campos,
      acciones: [
        AppBoton(
          texto: producto.activo ? 'Desactivar' : 'Activar',
          variante: BotonVariante.secundario,
          expandido: true,
          onPressed: () {
            Navigator.of(context).pop();
            onEstado();
          },
        ),
        AppBoton(
          texto: 'Editar',
          expandido: true,
          onPressed: () {
            Navigator.of(context).pop();
            onEditar();
          },
        ),
      ],
    );
  }
}
