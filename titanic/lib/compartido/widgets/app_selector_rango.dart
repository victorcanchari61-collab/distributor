import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Selector de un rango de días, con la forma de un campo.
///
/// El rango es opcional: sin él, [textoVacio] dice qué significa no haber
/// elegido ("Todas las fechas", "Este mes"). Cuando hay uno puesto sale una
/// equis para volver a ese estado sin abrir el calendario.
class AppSelectorRango extends StatelessWidget {
  const AppSelectorRango({
    super.key,
    required this.rango,
    required this.onCambio,
    this.textoVacio = 'Todas las fechas',
    this.habilitado = true,
    this.primerDia,
  });

  final DateTimeRange? rango;
  final ValueChanged<DateTimeRange?> onCambio;

  /// Lo que se lee cuando no hay rango elegido.
  final String textoVacio;

  final bool habilitado;

  /// El día más antiguo que se puede elegir. Sin él, dos años atrás.
  final DateTime? primerDia;

  @override
  Widget build(BuildContext context) {
    final elegido = rango;

    return InkWell(
      onTap: habilitado ? () => _elegir(context) : null,
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
      child: Container(
        height: Dimen.campoMd,
        padding: const EdgeInsets.only(left: Dimen.espacio3),
        decoration: BoxDecoration(
          color: Colores.superficie,
          border: Border.all(color: Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.date_range_outlined,
              size: 18,
              color: Colores.tintaSuave,
            ),
            const SizedBox(width: Dimen.espacio2),
            Expanded(
              child: Text(
                elegido == null
                    ? textoVacio
                    : '${_fecha(elegido.start)} — ${_fecha(elegido.end)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: elegido == null ? Colores.tintaSuave : Colores.tinta,
                ),
              ),
            ),
            if (elegido != null && habilitado)
              IconButton(
                onPressed: () => onCambio(null),
                tooltip: 'Quitar el rango',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: Colores.tintaTenue,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: Dimen.espacio3),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: Acento.de(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _elegir(BuildContext context) async {
    final hoy = DateTime.now();
    final elegido = await showDateRangePicker(
      context: context,
      initialDateRange: rango,
      firstDate: primerDia ?? DateTime(hoy.year - 2),
      // Hoy y no más allá: lo que se lee aquí ya pasó.
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
    );
    if (elegido != null) onCambio(elegido);
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
