import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// El botón que despliega los filtros, al lado del buscador.
///
/// Se pinta encendido tanto cuando el panel está abierto como cuando hay algún
/// filtro puesto: si no, al cerrarlo se perdería de vista que la lista sigue
/// recortada y parecería que faltan registros.
class BotonFiltrosEnLinea extends StatelessWidget {
  const BotonFiltrosEnLinea({super.key, required this.activo, required this.onTap});

  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
      child: Container(
        width: Dimen.campoMd,
        height: Dimen.campoMd,
        decoration: BoxDecoration(
          color: activo ? Acento.suave(context) : Colores.superficie,
          border: Border.all(color: activo ? Acento.de(context) : Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: Icon(Icons.tune, size: 18, color: activo ? Acento.de(context) : Colores.tintaSuave),
      ),
    );
  }
}

/// Un desplegable de filtro: "Todas · Categoría" o el valor elegido.
///
/// Se esconde solo si no hay de dónde elegir. Un filtro con una sola opción, o
/// con ninguna, no filtra nada y solo estorba en una pantalla estrecha.
class FiltroEnLinea extends StatelessWidget {
  const FiltroEnLinea({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  final String etiqueta;
  final String? valor;
  final List<String> opciones;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (opciones.isEmpty) return const SizedBox.shrink();

    return Container(
      height: Dimen.campoSm,
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: valor == null ? Colores.linea : Acento.de(context)),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: valor,
          hint: Text(etiqueta, style: const TextStyle(fontSize: 13, color: Colores.tintaSuave)),
          items: [
            DropdownMenuItem(value: null, child: Text('Todas · $etiqueta')),
            ...opciones.map((o) => DropdownMenuItem(value: o, child: Text(o))),
          ],
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: Colores.tinta),
        ),
      ),
    );
  }
}
