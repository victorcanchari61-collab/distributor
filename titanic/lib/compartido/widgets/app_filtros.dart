import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import 'app_boton.dart';
import 'app_selector.dart';

/// Una opcion dentro de un grupo de filtros.
class OpcionFiltro<T> {
  const OpcionFiltro(this.valor, this.texto);

  final T valor;
  final String texto;
}

/// Grupo de filtros de una sola eleccion.
///
/// Se pinta como select y no como pastillas: un rubro o una ruta pueden ser
/// decenas de opciones, y en pastillas el modal se volvia una pared de texto
/// por la que habia que hacer scroll.
class GrupoFiltro<T> extends StatelessWidget {
  const GrupoFiltro({
    super.key,
    required this.titulo,
    required this.valor,
    required this.opciones,
    required this.onCambio,
    this.icono,
  });

  final String titulo;
  final T valor;
  final List<OpcionFiltro<T>> opciones;
  final ValueChanged<T> onCambio;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return AppSelector<T>(
      valor: valor,
      etiqueta: titulo,
      icono: icono,
      opciones: [for (final o in opciones) Opcion(o.valor, o.texto)],
      onCambio: (v) {
        if (v is T) onCambio(v);
      },
    );
  }
}

/// Icono de filtros con el numero de los que estan puestos.
///
/// Va en el hueco de `filtro` de `AppListaPagina`, en el mismo lugar que el
/// embudo del panel web.
class BotonFiltros extends StatelessWidget {
  const BotonFiltros({
    super.key,
    required this.activos,
    required this.onAbrir,
    required this.color,
  });

  /// Cuantos filtros estan puestos. Cero deja el icono en gris y sin globo.
  final int activos;

  final VoidCallback onAbrir;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onAbrir,
      tooltip: 'Filtros',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.filter_list_rounded,
            size: 22,
            color: activos > 0 ? color : Colores.tintaSuave,
          ),
          if (activos > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$activos',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Modal de filtros.
///
/// Los grupos se arman en la pantalla; aqui viven la cabecera, el boton de
/// limpiar y el de aplicar, para que todos los listados filtren igual.
Future<void> mostrarFiltros(
  BuildContext context, {
  required List<Widget> grupos,
  required VoidCallback onLimpiar,
  int activos = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimen.radioPanel),
      ),
    ),
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimen.espacio4,
              0,
              Dimen.espacio4,
              Dimen.espacio3,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_list_rounded,
                  size: 20,
                  color: Colores.tintaSuave,
                ),
                const SizedBox(width: Dimen.espacio2),
                const Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colores.tinta,
                  ),
                ),
                const Spacer(),
                if (activos > 0)
                  TextButton(
                    onPressed: () {
                      onLimpiar();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Limpiar'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(Dimen.espacio4),
              itemCount: grupos.length,
              separatorBuilder: (context, i) =>
                  const SizedBox(height: Dimen.espacio4),
              itemBuilder: (context, i) => grupos[i],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Dimen.espacio4,
              Dimen.espacio3,
              Dimen.espacio4,
              Dimen.espacio4 + MediaQuery.of(context).padding.bottom,
            ),
            // La lista se filtra en vivo al elegir en cada select: este boton
            // solo cierra, pero hace falta para saber que se termino.
            child: AppBoton(
              texto: 'Ver resultados',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}
