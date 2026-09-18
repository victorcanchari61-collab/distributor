import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/catalogo_listo.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/lista_precio.dart';
import '../estado/facturacion_controlador.dart';
import 'lista_formulario.dart';
import 'precios_producto_formulario.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Listas de precios: catalogo de a cuanto se vende cada presentacion, con
/// escalones por volumen. En pestañas, una por lista.
class ListasPreciosPagina extends ConsumerWidget {
  const ListasPreciosPagina({super.key});

  static const ruta = '/fact/precios';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final listasAsync = ref.watch(listasPrecioProvider);
    final listas = listasAsync.valueOrNull ?? const <ListaPrecio>[];
    final activaId = ref.watch(listaPrecioActivaProvider);

    // Primera lista al cargar: la predeterminada si hay, si no la primera.
    if (activaId == null && listas.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final predeterminada = listas.where((l) => l.esPredeterminada).toList();
        ref.read(listaPrecioActivaProvider.notifier).state =
            (predeterminada.isNotEmpty ? predeterminada : listas).first.id;
      });
    }

    ListaPrecio? activa;
    for (final l in listas) {
      if (l.id == activaId) activa = l;
    }

    final precios = ref.watch(preciosFiltradosProvider);
    final productosConPrecio = precios.map((p) => p.productoId).toSet().length;
    final escalones = precios.where((p) => p.cantidadMinima > 1).length;

    return AppListaPagina<Precio>(
      titulo: 'Listas de precios',
      ruta: ruta,
      estado: ref.watch(preciosListaActivaProvider),
      visibles: precios,
      busqueda: ref.watch(busquedaPreciosProvider),
      onBuscar: (t) => ref.read(busquedaPreciosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por producto o presentación',
      onRecargar: () async {
        await ref.read(listasPrecioProvider.notifier).recargar();
        ref.invalidate(preciosListaActivaProvider);
      },
      onNuevo: activa == null || !puede(ref, 'fact.precios', Accion.crear)
          ? null
          : () => _abrirPrecios(context, ref, activa!),
      textoNuevo: 'Agregar precio',
      iconoVacio: Icons.payments_outlined,
      singular: 'precio',
      plural: 'precios',
      filtro: BotonFiltros(
        activos: ref.read(filtrosPreciosActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref, color),
      ),
      encabezado: Column(
        children: [
          _ListasTabs(
            listas: listas,
            valor: activaId,
            color: color,
            onCambio: (id) => ref.read(listaPrecioActivaProvider.notifier).state = id,
            onNueva: () => _nuevaLista(context, ref),
          ),
          // Las acciones de la LISTA van aqui, junto a sus pestañas, y no en
          // cada precio: actuan sobre la que esta abierta.
          if (activa != null &&
              (puede(ref, 'fact.precios', Accion.editar) ||
                  puede(ref, 'fact.precios', Accion.eliminar))) ...[
            const SizedBox(height: Dimen.espacio2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
              child: Row(
                children: [
                  if (puede(ref, 'fact.precios', Accion.editar))
                    Expanded(
                      child: AppBoton(
                        texto: 'Editar lista',
                        icono: Icons.edit_outlined,
                        variante: BotonVariante.secundario,
                        onPressed: () => mostrarFormularioLista(
                          context,
                          ref,
                          lista: activa,
                        ),
                      ),
                    ),
                  if (puede(ref, 'fact.precios', Accion.editar) &&
                      puede(ref, 'fact.precios', Accion.eliminar))
                    const SizedBox(width: Dimen.espacio2),
                  if (puede(ref, 'fact.precios', Accion.eliminar))
                    Expanded(
                      child: AppBoton(
                        texto: 'Eliminar lista',
                        icono: Icons.delete_outline,
                        variante: BotonVariante.secundario,
                        // La predeterminada no se borra: dejaria sin precio a
                        // todo cliente que no tenga lista propia.
                        onPressed: activa.esPredeterminada
                            ? null
                            : () => _eliminarLista(context, ref, activa!),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (activa != null && !activa.esPredeterminada) ...[
            const SizedBox(height: Dimen.espacio2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimen.espacio3,
                  vertical: Dimen.espacio2,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Dimen.radioCampo),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${activa.nombre} no es la lista predeterminada.',
                        style: const TextStyle(fontSize: 12.5, color: Colores.tinta),
                      ),
                    ),
                    AppBoton(
                      texto: 'Marcar predeterminada',
                      variante: BotonVariante.texto,
                      onPressed: () => _marcarPredeterminada(context, ref, activa!),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Precios en la lista',
          valor: '${precios.length}',
          icono: Icons.payments_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Productos con precio',
          valor: '$productosConPrecio',
          icono: Icons.inventory_2_outlined,
        ),
        AppTarjetaDato(
          etiqueta: 'Escalones por volumen',
          valor: '$escalones',
          icono: Icons.stacked_line_chart,
        ),
        AppTarjetaDato(
          etiqueta: 'Listas',
          valor: '${listas.length}',
          icono: Icons.sell_outlined,
        ),
      ],
      fila: (context, precio) => _TarjetaPrecio(
        precio: precio,
        color: color,
        onEditar: puede(ref, 'fact.precios', Accion.editar)
            ? () => _abrirPrecios(
                context,
                ref,
                activa!,
                productoId: precio.productoId,
              )
            : null,
        onEliminar: puede(ref, 'fact.precios', Accion.eliminar)
            ? () => _eliminarPrecio(context, ref, precio)
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref, Color color) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosPreciosActivosProvider),
      onLimpiar: () {
        ref.read(presentacionPrecioFiltroProvider.notifier).state = null;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) {
            final presentaciones = ref.watch(presentacionesDePreciosProvider);
            if (presentaciones.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Presentación',
              valor: ref.watch(presentacionPrecioFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todas'),
                for (final p in presentaciones) OpcionFiltro(p, p),
              ],
              onCambio: (v) =>
                  ref.read(presentacionPrecioFiltroProvider.notifier).state = v,
            );
          },
        ),
      ],
    );
  }

  Future<void> _nuevaLista(BuildContext context, WidgetRef ref) async {
    final creada = await mostrarFormularioLista(context, ref);
    if (creada != null) {
      ref.read(listaPrecioActivaProvider.notifier).state = creada.id;
    }
  }

  /*
   * Borra la lista abierta.
   *
   * El aviso dice de antemano lo que el backend va a rechazar —una con precios
   * cargados— para no hacer pulsar un boton que va a fallar. La regla vive en
   * el servidor igual; esto solo evita el viaje.
   */
  Future<void> _eliminarLista(
    BuildContext context,
    WidgetRef ref,
    ListaPrecio lista,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar ${lista.nombre}',
      mensaje: lista.precios > 0
          ? 'Tiene ${lista.precios} precio(s) cargado(s), asi que no se podra '
                'eliminar: vaciala primero.'
          : 'Se borra la lista. No afecta a los documentos ya emitidos con ella.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(listasPrecioProvider.notifier).eliminar(lista.id);
      // Al desaparecer la pestaña abierta hay que mover el foco, o la pantalla
      // queda mirando a una lista que ya no existe.
      ref.read(listaPrecioActivaProvider.notifier).state = null;
      mensajero.mostrar('${lista.nombre} eliminada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _marcarPredeterminada(BuildContext context, WidgetRef ref, ListaPrecio lista) async {
    final mensajero = Aviso.de(context);
    try {
      await ref.read(listasPrecioProvider.notifier).marcarPredeterminada(lista.id);
      mensajero.mostrar('${lista.nombre} es ahora la predeterminada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  /*
   * Agregar y editar abren el mismo editor, con TODAS las presentaciones del
   * producto a la vez —el kilo, las bolsas y el saco—, como en la web.
   *
   * Antes el telefono cargaba un precio suelto: para poner los siete de un
   * producto habia que abrir el formulario siete veces, y no habia forma de
   * ver el margen ni de poner el saco mas barato desde 5 unidades.
   */
  Future<void> _abrirPrecios(
    BuildContext context,
    WidgetRef ref,
    ListaPrecio lista, {
    int? productoId,
  }) async {
    // Los precios que ya tiene la lista: el editor los necesita para abrir
    // los tramos guardados y para saber cuales se quitaron.
    final precios = await catalogoListo(
      context,
      ref.read(preciosListaActivaProvider.future),
      queEs: 'los precios',
    );
    if (!context.mounted) return;
    await catalogoListo(
      context,
      ref.read(productosProvider.future),
      queEs: 'los productos',
    );
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreciosProductoFormulario(
          lista: lista,
          precios: precios,
          productoId: productoId,
        ),
      ),
    );
  }

  Future<void> _eliminarPrecio(BuildContext context, WidgetRef ref, Precio precio) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar precio de ${precio.producto}',
      mensaje: '${precio.presentacion}: S/ ${precio.precio.toStringAsFixed(2)}. No se puede deshacer.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(facturacionApiProvider).eliminarPrecio(precio.id);
      ref.invalidate(preciosListaActivaProvider);
      await ref.read(listasPrecioProvider.notifier).recargar();
      mensajero.mostrar('Precio eliminado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

class _ListasTabs extends StatelessWidget {
  const _ListasTabs({
    required this.listas,
    required this.valor,
    required this.color,
    required this.onCambio,
    required this.onNueva,
  });

  final List<ListaPrecio> listas;
  final int? valor;
  final Color color;
  final ValueChanged<int> onCambio;
  final VoidCallback onNueva;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
        itemCount: listas.length + 1,
        separatorBuilder: (context, i) => const SizedBox(width: Dimen.espacio2),
        itemBuilder: (context, i) {
          if (i == listas.length) {
            return ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Nueva lista'),
              onPressed: onNueva,
              visualDensity: VisualDensity.compact,
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              backgroundColor: Colores.superficie,
              side: const BorderSide(color: Colores.linea),
            );
          }

          final lista = listas[i];
          final activo = lista.id == valor;

          return ChoiceChip(
            avatar: Icon(
              lista.esPredeterminada ? Icons.star : Icons.sell_outlined,
              size: 15,
              color: activo ? color : Colores.tintaSuave,
            ),
            label: Text('${lista.nombre} (${lista.precios})'),
            selected: activo,
            onSelected: (_) => onCambio(lista.id),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: activo ? color : Colores.tintaSuave,
            ),
            backgroundColor: Colores.superficie,
            selectedColor: color.withValues(alpha: 0.12),
            side: BorderSide(color: activo ? color : Colores.linea),
          );
        },
      ),
    );
  }
}

class _TarjetaPrecio extends StatelessWidget {
  const _TarjetaPrecio({
    required this.precio,
    required this.color,
    this.onEditar,
    this.onEliminar,
  });

  final Precio precio;
  final Color color;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.payments_outlined,
      color: color,
      titulo: precio.producto,
      insignia: Text(
        'S/ ${precio.precio.toStringAsFixed(2)}',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
      ),
      campos: [
        CampoDetalle('Presentación', precio.presentacion),
        CampoDetalle(
          'Desde',
          precio.cantidadMinima <= 1
              ? 'Precio normal'
              : '${formatoNumero(precio.cantidadMinima)} a más',
        ),
        // Dos decimales: es plata, y cuatro solo hacian ruido. Es la columna
        // que muestra el negocio —el saco sale mas barato por kilo—.
        CampoDetalle(
          'Equivale a',
          'S/ ${precio.precioUnidadBase.toStringAsFixed(2)} × ${precio.unidadBase}',
        ),
      ],
      onTap: onEditar,
      acciones: [
        if (onEditar != null)
          IconButton(
            onPressed: onEditar,
            tooltip: 'Editar',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_outlined, size: 18, color: Acento.de(context)),
          ),
        if (onEliminar != null)
          IconButton(
            onPressed: onEliminar,
            tooltip: 'Eliminar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18, color: Colores.peligro),
          ),
      ],
    );
  }
}
