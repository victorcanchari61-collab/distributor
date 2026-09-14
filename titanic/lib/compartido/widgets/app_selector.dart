import 'package:flutter/material.dart';

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
    final campo = _campo(context);
    if (onCrear == null) return campo;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: campo),
        const SizedBox(width: Dimen.espacio2),
        IconButton(
          onPressed: habilitado ? onCrear : null,
          tooltip: etiquetaCrear,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: Colores.marcaSuave,
            foregroundColor: Colores.marca,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
        ),
      ],
    );
  }

  Widget _campo(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: valor,
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
        labelText: etiqueta,
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
