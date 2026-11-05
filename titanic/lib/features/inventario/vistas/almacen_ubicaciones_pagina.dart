import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/almacen.dart';
import '../estado/inventario_controlador.dart';

/// Los lugares de un almacen: pisos, cuartos y estantes, y que
/// producto esta puesto en cada uno.
///
/// Es de consulta: sirve para saber DONDE buscar la mercaderia. La estructura
/// se arma desde el panel web, que es donde se crean y se cambian los lugares.
class AlmacenUbicacionesPagina extends ConsumerWidget {
  const AlmacenUbicacionesPagina({super.key, required this.almacen});

  final Almacen almacen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Su propio Scaffold: declara aqui el acento del modulo, como el formulario.
    return Acento.modulo('inv', (context) {
      final lugares = ref.watch(ubicacionesProvider(almacen.id));

      return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ubicaciones',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Text(
                almacen.nombre,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colores.tintaSuave,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async => ref.refresh(ubicacionesProvider(almacen.id).future),
          child: lugares.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppVacio(
              icono: Icons.wifi_off_outlined,
              titulo: 'No se pudieron cargar los lugares',
              detalle: e is ApiExcepcion ? e.texto : null,
            ),
            data: (lista) => lista.isEmpty
                ? const AppVacio(
                    icono: Icons.layers_outlined,
                    titulo: 'Sin lugares definidos',
                    detalle:
                        'Este almacén todavía no tiene pisos, cuartos ni '
                        'estantes. Se arman desde el panel web.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(Dimen.espacio4),
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) => _FilaLugar(lugar: lista[i]),
                  ),
          ),
        ),
      );
    });
  }
}

class _FilaLugar extends StatelessWidget {
  const _FilaLugar({required this.lugar});

  final Ubicacion lugar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Cada nivel se hunde un escalon: asi se lee el arbol sin dibujar lineas.
      padding: EdgeInsets.only(left: lugar.nivel * 16.0),
      child: Opacity(
        opacity: lugar.activo ? 1 : 0.6,
        child: Material(
          color: Colores.superficie,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colores.linea),
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
            onTap: () => _verProductos(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimen.espacio3,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    lugar.hijos > 0
                        ? Icons.folder_open_outlined
                        : Icons.inventory_2_outlined,
                    size: 20,
                    color: Acento.de(context),
                  ),
                  const SizedBox(width: Dimen.espacio3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lugar.codigo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          lugar.nombre ?? lugar.tipoEtiqueta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colores.tintaSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!lugar.activo)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: AppEtiqueta('Inactivo'),
                    ),
                  if (lugar.productos > 0)
                    AppEtiqueta(
                      '${lugar.productos} ${lugar.productos == 1 ? 'producto' : 'productos'}',
                      tono: EtiquetaTono.modulo,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _verProductos(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colores.superficie,
      builder: (_) => _HojaProductos(lugar: lugar),
    );
  }
}

/// Lo que esta puesto en un lugar.
class _HojaProductos extends ConsumerWidget {
  const _HojaProductos({required this.lugar});

  final Ubicacion lugar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productos = ref.watch(productosUbicacionProvider(lugar.id));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimen.espacio4,
            0,
            Dimen.espacio4,
            Dimen.espacio4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lugar.tipoEtiqueta,
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
              Text(
                lugar.ruta,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colores.tinta,
                ),
              ),
              if (lugar.nombre != null)
                Text(
                  lugar.nombre!,
                  style: const TextStyle(color: Colores.tintaSuave),
                ),
              const SizedBox(height: Dimen.espacio3),
              Flexible(
                child: productos.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(Dimen.espacio5),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(Dimen.espacio4),
                    child: Text(e is ApiExcepcion ? e.texto : 'No se pudo cargar.'),
                  ),
                  data: (lista) => lista.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: Dimen.espacio5),
                          child: Center(
                            child: Text(
                              'No hay productos puestos en este lugar.',
                              style: TextStyle(color: Colores.tintaSuave),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: lista.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              lista[i].producto,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              [
                                lista[i].codigo,
                                if (lista[i].categoria != null) lista[i].categoria!,
                              ].join(' · '),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
