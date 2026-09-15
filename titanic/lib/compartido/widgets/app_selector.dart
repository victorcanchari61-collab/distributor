import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Una opcion del selector.
class Opcion<T> {
  const Opcion(this.valor, this.texto, {this.icono});

  final T valor;
  final String texto;

  /// Icono a la izquierda del texto, dentro del menu.
  final IconData? icono;
}

/// Selector del sistema, hermano de [AppCampo].
///
/// `DropdownButtonFormField` a secas abre un menu sin fondo ni esquinas
/// redondeadas: se ve el contenido de la pantalla por detras y las opciones no
/// se leen. Aqui se le da superficie, radio y sombra una sola vez, para que
/// ningun formulario tenga que acordarse de hacerlo.
class AppSelector<T> extends StatelessWidget {
  const AppSelector({
    super.key,
    required this.valor,
    required this.opciones,
    required this.etiqueta,
    required this.onCambio,
    this.icono,
    this.habilitado = true,
    this.error,
    this.onCrear,
    this.etiquetaCrear,
  });

  final T? valor;
  final List<Opcion<T>> opciones;
  final String etiqueta;
  final ValueChanged<T?> onCambio;

  /// Icono dentro del recuadro, igual que en [AppCampo].
  final IconData? icono;

  final bool habilitado;
  final String? error;

  /// Dar de alta lo que falta sin salir del formulario.
  ///
  /// El caso es siempre el mismo: se esta creando un producto y su categoria
  /// no existe todavia. Sin esto hay que abandonar lo escrito, ir al catalogo,
  /// crearla y volver a empezar. Con el + se crea ahi mismo y queda elegida.
  final VoidCallback? onCrear;

  /// Qué se crea, para el lector de pantalla: "Nueva categoría".
  final String? etiquetaCrear;

  @override
  Widget build(BuildContext context) {
    if (onCrear == null) return _campo(context);

    /*
     * El + va arriba, junto a la etiqueta, y no al costado del campo.
     *
     * Al costado le comia el ancho justo a lo que hay que leer —el nombre de
     * la categoria ya salia cortado como "Sin c..."— y en dos columnas el
     * problema se duplicaba. Arriba no le quita nada: ese renglon esta vacio.
     */
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                ),
              ),
              // Mismo boton que en la web: redondo, con el color del modulo
              // de fondo y sin efecto al tocarlo. GestureDetector y no InkWell
              // justamente por eso: el InkWell pinta su onda de tinta.
              GestureDetector(
                onTap: habilitado ? onCrear : null,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: habilitado
                        ? Acento.de(context).withValues(alpha: 0.12)
                        : Colores.tintaTenue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 14,
                    color: habilitado ? Acento.de(context) : Colores.tintaTenue,
                    semanticLabel: etiquetaCrear,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Sin labelText: la etiqueta ya esta arriba y repetirla flotando
        // dentro del recuadro seria decir dos veces lo mismo.
        _campo(context, conEtiqueta: false),
      ],
    );
  }

  Widget _campo(BuildContext context, {bool conEtiqueta = true}) {
    /*
     * Un valor que no esta en la lista revienta el desplegable.
     *
     * Pasa al dar de alta algo desde el propio formulario: se elige la marca
     * recien creada mientras el catalogo todavia trae la lista vieja, y entre
     * un dibujo y el otro el valor no tiene opcion. Tambien pasa al editar un
     * registro que apunta a un catalogo desactivado. En los dos casos vale
     * mas mostrar el campo vacio un instante que tumbar la pantalla.
     */
    final elegido = opciones.any((o) => o.valor == valor) ? valor : null;

    return DropdownButtonFormField<T>(
      initialValue: elegido,
      // isExpanded: sin esto el texto no cede espacio y el desplegable se
      // desborda en las cajas angostas.
      isExpanded: true,
      onChanged: habilitado ? onCambio : null,
      dropdownColor: Colores.superficie,
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
      elevation: 3,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 20,
        color: Colores.tintaSuave,
      ),
      style: const TextStyle(fontSize: 15, color: Colores.tinta),
      decoration: InputDecoration(
        labelText: conEtiqueta ? etiqueta : null,
        errorText: error,
        prefixIcon: icono == null
            ? null
            : Icon(icono, size: 19, color: Colores.tintaTenue),
        constraints: const BoxConstraints(minHeight: Dimen.campoLg),
      ),
      items: [
        for (final o in opciones)
          DropdownMenuItem(
            value: o.valor,
            child: Row(
              children: [
                if (o.icono != null) ...[
                  Icon(o.icono, size: 17, color: Colores.tintaSuave),
                  const SizedBox(width: Dimen.espacio2),
                ],
                Flexible(
                  child: Text(
                    o.texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
