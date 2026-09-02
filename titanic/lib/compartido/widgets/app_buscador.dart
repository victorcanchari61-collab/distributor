import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Buscador de un listado.
class AppBuscador extends StatelessWidget {
  const AppBuscador({
    super.key,
    required this.valor,
    required this.onCambio,
    this.pista = 'Buscar...',
  });

  final String valor;
  final ValueChanged<String> onCambio;
  final String pista;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: valor)
        ..selection = TextSelection.collapsed(offset: valor.length),
      onChanged: onCambio,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: pista,
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: Colores.tintaTenue,
        ),
        suffixIcon: valor.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Colores.tintaTenue,
                onPressed: () => onCambio(''),
                tooltip: 'Limpiar',
              ),
        constraints: const BoxConstraints(minHeight: Dimen.campoMd),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 0,
          horizontal: Dimen.espacio3,
        ),
      ),
    );
  }
}
