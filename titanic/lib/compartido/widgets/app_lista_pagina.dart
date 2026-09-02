import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navegacion/menu.dart';
import '../../core/red/excepciones.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import 'app_buscador.dart';
import 'app_shell.dart';
import 'app_vacio.dart';

/// Vista de listado del modulo.
///
/// Es el equivalente movil de `ListPage` en el panel web: el UNICO lugar donde
/// se decide como se arma un listado — buscador, contador, filtros, estados de
/// carga y error, tirar para recargar y el boton de crear. Las pantallas solo
/// dicen que datos hay y como se pinta cada fila.
class AppListaPagina<T> extends StatelessWidget {
  const AppListaPagina({
    super.key,
    required this.titulo,
    required this.ruta,
    required this.estado,
    required this.visibles,
    required this.busqueda,
    required this.onBuscar,
    required this.onRecargar,
    required this.fila,
    required this.iconoVacio,
    required this.singular,
    required this.plural,
    this.pistaBusqueda,
    this.onNuevo,
    this.textoNuevo = 'Nuevo',
    this.filtro,
    this.tituloVacio,
    this.detalleVacio,
  });

  final String titulo;

  /// Ruta del menu: de ahi salen el color y el nombre del modulo.
  final String ruta;

  /// Estado de la carga. La lista que trae no se usa para pintar: para eso
  /// esta `visibles`, que ya viene filtrada.
  final AsyncValue<List<T>> estado;
  final List<T> visibles;

  final String busqueda;
  final ValueChanged<String> onBuscar;
  final String? pistaBusqueda;

  final Future<void> Function() onRecargar;

  final Widget Function(BuildContext context, T item) fila;

  final VoidCallback? onNuevo;
  final String textoNuevo;

  /// Controles propios de la pantalla junto al contador, como el interruptor
  /// de desactivados.
  final Widget? filtro;

  final IconData iconoVacio;
  final String singular;
  final String plural;
  final String? tituloVacio;
  final String? detalleVacio;

  @override
  Widget build(BuildContext context) {
    final grupo = resolverRuta(ruta).grupo;
    final color = grupo?.color ?? Colores.marca;

    return AppShell(
      titulo: titulo,
      subtitulo: grupo?.titulo,
      acentado: color,
      rutaActual: ruta,
      accionFlotante: onNuevo == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onNuevo,
              backgroundColor: color,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(textoNuevo),
            ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Dimen.espacio4),
            child: Column(
              children: [
                AppBuscador(
                  valor: busqueda,
                  onCambio: onBuscar,
                  pista: pistaBusqueda ?? 'Buscar',
                ),
                const SizedBox(height: Dimen.espacio3),
                Row(
                  children: [
                    // Flexible: el conteo cede espacio antes que empujar los
                    // filtros fuera de la fila.
                    Flexible(
                      child: Text(
                        '${visibles.length} '
                        '${visibles.length == 1 ? singular : plural}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colores.tintaSuave,
                        ),
                      ),
                    ),
                    const Spacer(),
                    ?filtro,
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: estado.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, pila) => AppVacio(
                icono: Icons.wifi_off_outlined,
                titulo: 'No se pudo cargar',
                detalle: e is ApiExcepcion
                    ? e.texto
                    : 'No pudimos cargar ${plural.toLowerCase()}.',
                accion: FilledButton.icon(
                  onPressed: () => onRecargar(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                ),
              ),
              data: (_) => visibles.isEmpty
                  ? AppVacio(
                      icono: iconoVacio,
                      titulo: tituloVacio ?? 'Sin $plural',
                      detalle:
                          detalleVacio ??
                          (busqueda.isEmpty
                              ? 'Registra el primero con el botón de abajo.'
                              : 'Ninguno coincide con lo que buscaste.'),
                    )
                  : RefreshIndicator(
                      onRefresh: onRecargar,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          Dimen.espacio4,
                          0,
                          Dimen.espacio4,
                          // Hueco al final para que el boton flotante no tape
                          // la ultima fila.
                          Dimen.espacio6 * 2,
                        ),
                        itemCount: visibles.length,
                        separatorBuilder: (context, i) =>
                            const SizedBox(height: Dimen.espacio2),
                        itemBuilder: (context, i) => fila(context, visibles[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
