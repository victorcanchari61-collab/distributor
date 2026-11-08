import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_pestanas.dart';
import '../../../compartido/widgets/app_sin_permiso.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/sin_permiso.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/almacen.dart';
import '../estado/inventario_controlador.dart';

const _submodulo = 'inv.ubicaciones';

/// Ubicacion de productos: donde esta puesto cada producto dentro del almacen.
///
/// Sirve para saber DONDE buscar la mercaderia y para ordenar: "Sin lugar" son
/// los productos que tienen stock y nadie sabe donde estan. El stock sigue
/// siendo por almacen, no por cuarto.
class UbicacionProductosPagina extends ConsumerWidget {
  const UbicacionProductosPagina({super.key});

  static const ruta = '/inv/ubicaciones';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final almacenes = ref.watch(almacenesActivosProvider);

    // Sin elegir, el principal (o el primero que haya).
    final elegido = ref.watch(almacenUbicacionProvider);
    final almacenId =
        elegido ??
        (almacenes.isEmpty
            ? null
            : (almacenes.where((a) => a.esPrincipal).firstOrNull ??
                      almacenes.first)
                  .id);

    if (almacenId == null) {
      return AppListaPagina<ProductoUbicado>(
        titulo: 'Ubicación de productos',
        ruta: ruta,
        estado: const AsyncValue.data([]),
        visibles: const [],
        busqueda: '',
        onBuscar: (_) {},
        onRecargar: () async => ref.invalidate(almacenesOpcionesProvider),
        fila: (_, _) => const SizedBox.shrink(),
        iconoVacio: Icons.warehouse_outlined,
        singular: 'producto',
        plural: 'productos',
        tituloVacio: 'No hay almacenes',
      );
    }

    final datos = ref.watch(productosUbicadosProvider(almacenId));
    final soloSin = ref.watch(soloSinLugarProvider);
    final texto = ref.watch(busquedaUbicacionProvider).trim().toLowerCase();

    final items = datos.valueOrNull?.items ?? const <ProductoUbicado>[];
    final visibles = [
      for (final p in items)
        if ((!soloSin || p.sinLugar) &&
            (texto.isEmpty || p.buscable.contains(texto)))
          p,
    ];
    final sinLugar = datos.valueOrNull?.sinLugar ?? 0;

    return AppListaPagina<ProductoUbicado>(
      titulo: 'Ubicación de productos',
      ruta: ruta,
      estado: datos.whenData((d) => d.items),
      visibles: visibles,
      busqueda: ref.watch(busquedaUbicacionProvider),
      onBuscar: (t) => ref.read(busquedaUbicacionProvider.notifier).state = t,
      pistaBusqueda: 'Buscar producto, código o lugar',
      onRecargar: () async {
        ref.invalidate(ubicacionesProvider(almacenId));
        ref.invalidate(productosUbicadosProvider(almacenId));
        await ref.read(productosUbicadosProvider(almacenId).future);
      },
      iconoVacio: Icons.place_outlined,
      singular: 'producto',
      plural: 'productos',
      detalleVacio: soloSin ? 'Todos los productos tienen lugar.' : null,
      pestanas: almacenes.length < 2
          ? null
          : AppPestanas<int>(
              activa: almacenId,
              onCambio: (v) =>
                  ref.read(almacenUbicacionProvider.notifier).state = v,
              pestanas: [
                for (final a in almacenes)
                  Pestana<int>(a.id, a.nombre, icono: Icons.warehouse_outlined),
              ],
            ),
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Productos',
          valor: '${items.length}',
          icono: Icons.inventory_2_outlined,
          color: color,
          nota: 'con stock o ya ubicados',
        ),
        AppTarjetaDato(
          etiqueta: 'Sin lugar',
          valor: '$sinLugar',
          icono: Icons.report_problem_outlined,
          tono: sinLugar > 0 ? DatoTono.aviso : DatoTono.exito,
          nota: 'nadie sabe dónde están',
        ),
        AppTarjetaDato(
          etiqueta: 'Lugares definidos',
          valor: '${datos.valueOrNull?.lugares ?? 0}',
          icono: Icons.layers_outlined,
          tono: DatoTono.neutral,
        ),
      ],
      filtro: FilterChip(
        label: const Text('Solo sin lugar'),
        selected: soloSin,
        onSelected: (v) => ref.read(soloSinLugarProvider.notifier).state = v,
      ),
      fila: (context, producto) => _TarjetaProducto(
        producto: producto,
        color: color,
        onPoner: permitir(
          puede(ref, _submodulo, Accion.editar),
          () => _poner(context, ref, almacenId, producto),
        ),
      ),
    );
  }

  /// Elige el lugar y lo pone: si ya tenia uno, lo mueve (queda en un solo lugar).
  Future<void> _poner(
    BuildContext context,
    WidgetRef ref,
    int almacenId,
    ProductoUbicado producto,
  ) async {
    final mensajero = Aviso.de(context);

    List<Ubicacion> lugares;
    try {
      lugares = await ref.read(ubicacionesProvider(almacenId).future);
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
      return;
    }

    final activos = lugares.where((l) => l.activo).toList();
    if (!context.mounted) return;
    if (activos.isEmpty) {
      mensajero.error(
        'Este almacén no tiene lugares: créalos desde el panel web.',
      );
      return;
    }

    final lugar = await showModalBottomSheet<Ubicacion>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colores.superficie,
      builder: (_) => _HojaLugares(producto: producto, lugares: activos),
    );
    if (lugar == null) return;

    try {
      await ref
          .read(inventarioApiProvider)
          .asignarUbicacion(
            ubicacionId: lugar.id,
            productoIds: [producto.productoId],
            reemplazar: true,
          );
      ref.invalidate(productosUbicadosProvider(almacenId));
      ref.invalidate(ubicacionesProvider(almacenId));
      mensajero.mostrar('${producto.producto} puesto en ${lugar.ruta}');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

class _TarjetaProducto extends StatelessWidget {
  const _TarjetaProducto({
    required this.producto,
    required this.color,
    this.onPoner,
  });

  final ProductoUbicado producto;
  final Color color;

  /// Null si quien mira no puede cambiar ubicaciones.
  final VoidCallback? onPoner;

  Widget get _estado => producto.sinLugar
      ? const AppEtiqueta('Sin lugar', tono: EtiquetaTono.aviso)
      : AppEtiqueta(producto.lugares.first.ruta, tono: EtiquetaTono.exito);

  List<CampoDetalle> get _campos => [
    CampoDetalle('Código', producto.codigo, enTarjeta: false),
    CampoDetalle('Categoría', producto.categoria, enTarjeta: false),
    CampoDetalle(
      'Stock',
      producto.stock > 0
          ? '${formatoNumero(producto.stock)} ${producto.unidadBase}'
          : null,
    ),
    CampoDetalle(
      'Dónde está',
      producto.sinLugar
          ? null
          : producto.lugares.map((l) => l.ruta).join(' · '),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.place_outlined,
      color: color,
      titulo: producto.producto,
      insignia: _estado,
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: Icons.place_outlined,
        color: color,
        titulo: producto.producto,
        subtitulo: producto.codigo,
        estado: _estado,
        campos: _campos,
        acciones: [
          if (onPoner != null)
            AppBoton(
              texto: producto.sinLugar
                  ? 'Poner en un lugar'
                  : 'Mover a otro lugar',
              expandido: true,
              onPressed: cerrandoHoja(context, onPoner),
            ),
        ],
      ),
      acciones: [
        if (onPoner != null)
          IconButton(
            onPressed: onPoner,
            tooltip: producto.sinLugar ? 'Poner en un lugar' : 'Mover',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              producto.sinLugar
                  ? Icons.add_location_alt_outlined
                  : Icons.edit_location_alt_outlined,
              size: 18,
              color: Acento.de(context),
            ),
          ),
      ],
    );
  }
}

/// El arbol de lugares del almacen para elegir uno.
class _HojaLugares extends StatelessWidget {
  const _HojaLugares({required this.producto, required this.lugares});

  final ProductoUbicado producto;
  final List<Ubicacion> lugares;

  @override
  Widget build(BuildContext context) {
    final actuales = producto.lugares.map((l) => l.ubicacionId).toSet();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimen.espacio4,
                0,
                Dimen.espacio4,
                Dimen.espacio2,
              ),
              child: Text(
                'Elegir lugar para ${producto.producto}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colores.tinta,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: lugares.length,
                itemBuilder: (context, i) {
                  final l = lugares[i];
                  final aqui = actuales.contains(l.id);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.only(
                      left: Dimen.espacio4 + l.nivel * 16.0,
                      right: Dimen.espacio4,
                    ),
                    leading: Icon(
                      l.hijos > 0
                          ? Icons.folder_open_outlined
                          : Icons.inventory_2_outlined,
                      size: 20,
                      color: Acento.de(context),
                    ),
                    title: Text(
                      l.nombre == null ? l.codigo : '${l.codigo} · ${l.nombre}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(l.ruta),
                    trailing: aqui
                        ? const AppEtiqueta('Aquí', tono: EtiquetaTono.exito)
                        : null,
                    onTap: aqui ? null : () => Navigator.of(context).pop(l),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
