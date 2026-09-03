import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/lista_precio.dart';
import '../estado/facturacion_controlador.dart';
import 'lista_formulario.dart';
import 'precio_formulario.dart';

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
      onNuevo: activa == null ? null : () => _agregarPrecio(context, ref, activa!),
      textoNuevo: 'Agregar precio',
      iconoVacio: Icons.payments_outlined,
      singular: 'precio',
      plural: 'precios',
      encabezado: Column(
        children: [
          _ListasTabs(
            listas: listas,
            valor: activaId,
            color: color,
            onCambio: (id) => ref.read(listaPrecioActivaProvider.notifier).state = id,
            onNueva: () => _nuevaLista(context, ref),
          ),
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
        onEditar: () => _editarPrecio(context, ref, activa!, precio),
        onEliminar: () => _eliminarPrecio(context, ref, precio),
      ),
    );
  }

  Future<void> _nuevaLista(BuildContext context, WidgetRef ref) async {
    final creada = await mostrarFormularioLista(context, ref);
    if (creada != null) {
      ref.read(listaPrecioActivaProvider.notifier).state = creada.id;
    }
  }

  Future<void> _marcarPredeterminada(BuildContext context, WidgetRef ref, ListaPrecio lista) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(listasPrecioProvider.notifier).marcarPredeterminada(lista.id);
      mensajero.showSnackBar(SnackBar(content: Text('${lista.nombre} es ahora la predeterminada')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }

  Future<void> _agregarPrecio(BuildContext context, WidgetRef ref, ListaPrecio lista) async {
    final productos = ref.read(productosProvider).valueOrNull ?? const <Producto>[];
    final nuevo = await mostrarFormularioPrecio(context, productos: productos);
    if (nuevo == null || !context.mounted) return;
    await _guardarPrecio(context, ref, lista, nuevo);
  }

  Future<void> _editarPrecio(
    BuildContext context,
    WidgetRef ref,
    ListaPrecio lista,
    Precio existente,
  ) async {
    final productos = ref.read(productosProvider).valueOrNull ?? const <Producto>[];
    final editado = await mostrarFormularioPrecio(context, productos: productos, existente: existente);
    if (editado == null || !context.mounted) return;
    await _guardarPrecio(context, ref, lista, editado, reemplazando: existente);
  }

  Future<void> _guardarPrecio(
    BuildContext context,
    WidgetRef ref,
    ListaPrecio lista,
    NuevoPrecio nuevo, {
    Precio? reemplazando,
  }) async {
    final actuales = ref.read(preciosListaActivaProvider).valueOrNull ?? const <Precio>[];
    final arreglo = [
      for (final p in actuales)
        if (reemplazando == null || p.id != reemplazando.id)
          {
            'presentacionId': p.presentacionId,
            'precio': p.precio,
            'cantidadMinima': p.cantidadMinima,
          },
      nuevo.aCuerpo(),
    ];

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(facturacionApiProvider).guardarPrecios(lista.id, arreglo);
      ref.invalidate(preciosListaActivaProvider);
      await ref.read(listasPrecioProvider.notifier).recargar();
      mensajero.showSnackBar(const SnackBar(content: Text('Precio guardado')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
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

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(facturacionApiProvider).eliminarPrecio(precio.id);
      ref.invalidate(preciosListaActivaProvider);
      await ref.read(listasPrecioProvider.notifier).recargar();
      mensajero.showSnackBar(const SnackBar(content: Text('Precio eliminado')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
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
    required this.onEditar,
    required this.onEliminar,
  });

  final Precio precio;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

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
          precio.cantidadMinima <= 1 ? 'Precio normal' : '${precio.cantidadMinima}',
        ),
        CampoDetalle(
          'Por ${precio.unidadBase}',
          'S/ ${precio.precioUnidadBase.toStringAsFixed(4)}',
        ),
      ],
      onTap: onEditar,
      acciones: [
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined, size: 18, color: Colores.marca),
        ),
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
