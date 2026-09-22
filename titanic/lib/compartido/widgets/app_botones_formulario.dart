import 'package:flutter/material.dart';

import '../../core/tema/dimensiones.dart';
import 'app_boton.dart';

/// Cancelar y guardar, uno al lado del otro, al pie de un formulario.
///
/// Antes cada formulario tenia su propio par apilado —un boton ancho arriba
/// con el nombre de la entidad ("Registrar transferencia", "Registrar
/// pedido", "Crear proveedor"...) y "Cancelar" abajo—, y ese nombre no decia
/// nada que el propio formulario no dijera ya. Ahora es una sola fila, con
/// el mismo texto en todos lados.
class AppBotonesFormulario extends StatelessWidget {
  const AppBotonesFormulario({
    super.key,
    required this.onCancelar,
    required this.onGuardar,
    this.textoGuardar = 'Registrar',
    this.cargando = false,
  });

  final VoidCallback onCancelar;
  final VoidCallback? onGuardar;
  final String textoGuardar;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppBoton(
            texto: 'Cancelar',
            variante: BotonVariante.secundario,
            onPressed: cargando ? null : onCancelar,
          ),
        ),
        const SizedBox(width: Dimen.espacio2),
        Expanded(
          child: AppBoton(
            texto: textoGuardar,
            cargando: cargando,
            onPressed: onGuardar,
          ),
        ),
      ],
    );
  }
}
