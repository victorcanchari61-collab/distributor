import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import 'app_boton.dart';
import 'app_hoja.dart';
import 'app_selector.dart';
import 'app_selector_rango.dart';

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

/// Un rango de fechas dentro de la hoja de filtros, igual que en el panel web:
/// las fechas se filtran con el embudo, no con un control aparte arriba de la
/// lista.
class GrupoFiltroFechas extends StatelessWidget {
  const GrupoFiltroFechas({
    super.key,
    required this.rango,
    required this.onCambio,
    this.titulo = 'Fechas',
    this.textoVacio = 'Todas las fechas',
  });

  final DateTimeRange? rango;
  final ValueChanged<DateTimeRange?> onCambio;
  final String titulo;

  /// Lo que se lee sin rango elegido: "Hoy", "Todas las fechas".
  final String textoVacio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colores.tintaSuave,
            ),
          ),
        ),
        AppSelectorRango(
          rango: rango,
          textoVacio: textoVacio,
          onCambio: onCambio,
        ),
      ],
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
  return abrirHoja<void>(
    context,
    (context) => HojaBase(
      titulo: 'Filtros',
      accionesTitulo: [
        if (activos > 0)
          TextButton(
            onPressed: () {
              onLimpiar();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Limpiar'),
          ),
      ],
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < grupos.length; i++) ...[
            if (i > 0) const SizedBox(height: Dimen.espacio4),
            grupos[i],
          ],
        ],
      ),
      // La lista se filtra en vivo al elegir en cada select: este boton solo
      // cierra, pero hace falta para saber que se termino.
      pie: AppBoton(
        texto: 'Ver resultados',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
  );
}
