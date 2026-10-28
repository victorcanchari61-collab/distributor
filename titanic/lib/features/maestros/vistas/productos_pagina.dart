import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/exportar_csv.dart';
import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_catalogo_simple.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_pestanas.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/catalogo.dart';
import '../datos/producto.dart';
import '../estado/maestros_controlador.dart';
import 'producto_formulario.dart';
import 'unidades_pestana.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Recarga un catálogo de apoyo y espera la lista nueva.
Future<void> _recargarCatalogo(
  WidgetRef ref,
  AutoDisposeFutureProvider<Object?> provider,
) async {
  ref.invalidate(provider);
  try {
    await ref.read(provider.future);
  } catch (_) {
    // El fallo ya se ve en la pantalla, con su botón de reintentar.
  }
}

/// Productos, con sus catálogos de apoyo en pestañas: Productos, Categorías,
/// Marcas y Unidades, igual que el panel web. Cada pestaña muestra cuántos
/// registros tiene.
class ProductosPagina extends ConsumerWidget {
  const ProductosPagina({super.key});

  static const ruta = '/maestros/productos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final pestana = ref.watch(pestanaProductosProvider);

    // Las mismas pestañas van arriba de cada vista, para que no se muevan al
    // cambiar de una a otra.
    final pestanas = AppPestanas<PestanaProductos>(
      activa: pestana,
      onCambio: (p) => ref.read(pestanaProductosProvider.notifier).state = p,
      pestanas: [
        Pestana(
          PestanaProductos.productos,
          'Productos',
          icono: Icons.inventory_2_outlined,
          contador: ref.watch(productosProvider).valueOrNull?.length,
        ),
        Pestana(
          PestanaProductos.categorias,
          'Categorías',
          icono: Icons.category_outlined,
          contador: ref.watch(categoriasProvider).valueOrNull?.length,
        ),
        Pestana(
          PestanaProductos.marcas,
          'Marcas',
          icono: Icons.sell_outlined,
          contador: ref.watch(marcasProvider).valueOrNull?.length,
        ),
        Pestana(
          PestanaProductos.unidades,
          'Unidades',
          icono: Icons.straighten_outlined,
          contador: ref.watch(unidadesProvider).valueOrNull?.length,
        ),
      ],
    );

    return switch (pestana) {
      PestanaProductos.productos => _productos(context, ref, color, pestanas),
      PestanaProductos.categorias => _categorias(ref, color, pestanas),
      PestanaProductos.marcas => _marcas(ref, color, pestanas),
      PestanaProductos.unidades => UnidadesPestana(
        titulo: 'Productos',
        ruta: ruta,
        pestanas: pestanas,
      ),
    };
  }

  /// Categorías: nombre, descripción y cuántos productos la usan.
  Widget _categorias(WidgetRef ref, Color color, Widget pestanas) {
    final api = ref.read(maestrosApiProvider);
    // El acento se declara aquí: el catálogo lo lee en su propio build, por
    // encima del AppShell que lo pondría.
    return Acento(
      color: color,
      child: AppCatalogoSimple(
        // Con clave: sin ella Categorías y Marcas comparten el estado (y el
        // texto del buscador) al pasar de una a otra.
        key: const ValueKey(PestanaProductos.categorias),
        titulo: 'Productos',
        ruta: ruta,
        pestanas: pestanas,
        estado: ref
            .watch(categoriasProvider)
            .whenData(
              (lista) => [
                for (final c in lista)
                  FilaCatalogo(
                    id: c.id,
                    nombre: c.nombre,
                    descripcion: c.descripcion,
                    activo: c.activo,
                    usos: c.productos,
                  ),
              ],
            ),
        singular: 'categoría',
        plural: 'categorías',
        icono: Icons.category_outlined,
        conDescripcion: true,
        onRecargar: () => _recargarCatalogo(ref, categoriasProvider),
        onCrear: (cuerpo) => api.crearCategoria(cuerpo),
        onActualizar: (id, cuerpo) => api.actualizarCategoria(id, cuerpo),
        onEliminar: (id) => api.eliminarCategoria(id),
        puedeCrear: puede(ref, 'maestros.productos', Accion.crear),
        puedeEditar: puede(ref, 'maestros.productos', Accion.editar),
        puedeEliminar: puede(ref, 'maestros.productos', Accion.eliminar),
      ),
    );
  }

  /// Marcas: solo el nombre, sin descripción, como en la web.
  Widget _marcas(WidgetRef ref, Color color, Widget pestanas) {
    final api = ref.read(maestrosApiProvider);
    return Acento(
      color: color,
      child: AppCatalogoSimple(
        key: const ValueKey(PestanaProductos.marcas),
        titulo: 'Productos',
        ruta: ruta,
        pestanas: pestanas,
        estado: ref
            .watch(marcasProvider)
            .whenData(
              (lista) => [
                for (final m in lista)
                  FilaCatalogo(
                    id: m.id,
                    nombre: m.nombre,
                    activo: m.activo,
                    usos: m.productos,
                  ),
              ],
            ),
        singular: 'marca',
        plural: 'marcas',
        icono: Icons.sell_outlined,
        onRecargar: () => _recargarCatalogo(ref, marcasProvider),
        // La marca solo lleva nombre (y activo al actualizar).
        onCrear: (cuerpo) => api.crearMarca({'nombre': cuerpo['nombre']}),
        onActualizar: (id, cuerpo) => api.actualizarMarca(id, {
          'nombre': cuerpo['nombre'],
          'activo': cuerpo['activo'],
        }),
        onEliminar: (id) => api.eliminarMarca(id),
        puedeCrear: puede(ref, 'maestros.productos', Accion.crear),
        puedeEditar: puede(ref, 'maestros.productos', Accion.editar),
        puedeEliminar: puede(ref, 'maestros.productos', Accion.eliminar),
      ),
    );
  }

  /// El listado de productos de siempre, como primera pestaña.
  Widget _productos(
    BuildContext context,
    WidgetRef ref,
    Color color,
    Widget pestanas,
  ) {
    final todos =
        ref.watch(productosProvider).valueOrNull ?? const <Producto>[];
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
      pestanas: pestanas,
      estado: ref.watch(productosProvider),
      visibles: ref.watch(productosFiltradosProvider),
      busqueda: ref.watch(busquedaProductosProvider),
      onBuscar: (t) => ref.read(busquedaProductosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por nombre, código o categoría',
      onRecargar: () => ref.read(productosProvider.notifier).recargar(),
      onNuevo: puede(ref, 'maestros.productos', Accion.crear)
          ? () => _abrirFormulario(context, null)
          : null,
      acciones: [
        if (puede(ref, 'maestros.productos', Accion.exportar))
          accionExportar<Producto>(
            context,
            nombre: 'productos',
            filas: () => ref.read(productosFiltradosProvider),
            encabezados: const [
              'Código',
              'Producto',
              'Categoría',
              'Marca',
              'Unidad base',
              'Costo de referencia',
              'Precio de referencia',
              'Afecto a IGV',
              'Stock mínimo',
              'Estado',
            ],
            fila: (p) => [
              p.codigo,
              p.nombre,
              p.categoria,
              p.marca,
              p.unidadBase,
              p.costoReferencia,
              p.precioReferencia,
              p.afectoIgv ? 'Sí' : 'No',
              p.stockMinimo,
              p.activo ? 'Activo' : 'Desactivado',
            ],
          ),
      ],
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
        onEditar: puede(ref, 'maestros.productos', Accion.editar)
            ? () => _abrirFormulario(context, producto)
            : null,
        onEstado: puede(ref, 'maestros.productos', Accion.editar)
            ? () => _cambiarEstado(context, ref, producto)
            : null,
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
        ref.read(unidadBaseFiltroProvider.notifier).state = null;
        ref.read(presentacionUnidadFiltroProvider.notifier).state = null;
        ref.read(conCostoFiltroProvider.notifier).state = null;
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
        Consumer(
          builder: (context, ref, _) {
            final unidades = ref.watch(unidadesBaseProductoProvider);
            if (unidades.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Unidad base',
              valor: ref.watch(unidadBaseFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todas'),
                for (final u in unidades) OpcionFiltro(u, u),
              ],
              onCambio: (v) =>
                  ref.read(unidadBaseFiltroProvider.notifier).state = v,
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final unidades = ref.watch(unidadesPresentacionProductoProvider);
            if (unidades.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Presentaciones',
              valor: ref.watch(presentacionUnidadFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todas'),
                for (final u in unidades) OpcionFiltro(u, 'Se vende en $u'),
              ],
              onCambio: (v) =>
                  ref.read(presentacionUnidadFiltroProvider.notifier).state = v,
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<bool?>(
            titulo: 'Costo referencial',
            valor: ref.watch(conCostoFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todos'),
              OpcionFiltro(true, 'Con costo'),
              OpcionFiltro(false, 'Sin costo'),
            ],
            onCambio: (v) =>
                ref.read(conCostoFiltroProvider.notifier).state = v,
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
      titulo:
          '${producto.activo ? 'Desactivar' : 'Activar'} ${producto.nombre}',
      mensaje: producto.activo
          ? 'Deja de aparecer para nuevas operaciones, pero conserva su historial y puedes volver a activarlo.'
          : 'Vuelve a estar disponible para usarse.',
      textoConfirmar: producto.activo ? 'Desactivar' : 'Activar',
      tono: producto.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);

    try {
      await ref.read(productosProvider.notifier).cambiarEstado(producto);
      mensajero.mostrar(
        producto.activo
            ? '${producto.nombre} desactivado'
            : '${producto.nombre} activado',
      );
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

class _TarjetaProducto extends StatelessWidget {
  const _TarjetaProducto({
    required this.producto,
    required this.color,
    this.onEditar,
    this.onEstado,
  });

  final Producto producto;
  final Color color;
  final VoidCallback? onEditar;
  final VoidCallback? onEstado;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Marca', producto.marca),
    CampoDetalle('Categoría', producto.categoria, enTarjeta: false),
    CampoDetalle('Unidad base', producto.unidadBase),
    CampoDetalle(
      'Costo referencia',
      producto.costoReferencia == null
          ? null
          : 'S/ ${formatoCosto(producto.costoReferencia!)}',
    ),
    CampoDetalle(
      'Presentaciones',
      producto.presentaciones.length == 1
          ? '1 presentación'
          : '${producto.presentaciones.length} presentaciones',
      enTarjeta: false,
    ),
    // Ya no se dice si controla stock —todos lo hacen— sino desde cuanto
    // avisa, que es el dato que se consulta.
    CampoDetalle(
      'Stock mínimo',
      producto.stockMinimo > 0
          ? '${formatoNumero(producto.stockMinimo)} ${producto.unidadBase}'
          : 'Sin aviso',
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
        if (onEditar != null)
          IconButton(
            onPressed: onEditar,
            tooltip: 'Editar',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: Acento.de(context),
            ),
          ),
        if (onEstado != null)
          IconButton(
            onPressed: onEstado,
            tooltip: producto.activo ? 'Desactivar' : 'Activar',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              producto.activo ? Icons.block : Icons.check_circle_outline,
              size: 18,
              color: Colores.advertencia,
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
      estado: producto.activo
          ? null
          : const AppEtiqueta('Inactivo', tono: EtiquetaTono.aviso),
      campos: _campos,
      acciones: [
        if (onEstado != null)
          AppBoton(
            texto: producto.activo ? 'Desactivar' : 'Activar',
            variante: BotonVariante.secundario,
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onEstado!();
            },
          ),
        if (onEditar != null)
          AppBoton(
            texto: 'Editar',
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onEditar!();
            },
          ),
      ],
    );
  }
}
