import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
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
    // Igual que el buscador del panel web: fondo blanco y el borde del color del
    // módulo siempre visible (no solo al tocarlo), más fuerte con el foco.
    final acento = Acento.de(context);
    OutlineInputBorder borde(Color color, [double ancho = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
          borderSide: BorderSide(color: color, width: ancho),
        );

    return TextField(
      controller: TextEditingController(text: valor)
        ..selection = TextSelection.collapsed(offset: valor.length),
      onChanged: onCambio,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: pista,
        filled: true,
        fillColor: Colores.superficie,
        border: borde(acento.withValues(alpha: 0.55)),
        enabledBorder: borde(acento.withValues(alpha: 0.55)),
        focusedBorder: borde(acento, 1.5),
        prefixIcon: Icon(Icons.search, size: 20, color: acento),
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
