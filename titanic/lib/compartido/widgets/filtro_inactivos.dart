import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';

/// Interruptor para ver los registros desactivados.
///
/// Va en el hueco de `filtro` de [AppListaPagina]. Es un interruptor y no dos
/// pestañas porque ocupa menos y deja claro que se esta viendo otra lista.
class FiltroInactivos extends StatelessWidget {
  const FiltroInactivos({
    super.key,
    required this.activo,
    required this.onCambio,
    this.etiqueta = 'Desactivados',
  });

  final bool activo;
  final ValueChanged<bool> onCambio;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 12.5,
            color: activo ? Colores.advertencia : Colores.tintaSuave,
            fontWeight: activo ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Switch(
          value: activo,
          onChanged: onCambio,
          activeThumbColor: Colores.advertencia,
        ),
      ],
    );
  }
}
