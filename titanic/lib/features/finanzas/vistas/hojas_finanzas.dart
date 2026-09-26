import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';

/// Lo que repiten las hojas y listas de Finanzas: abrir una hoja con el acento
/// del modulo, el margen para el teclado y como se escriben montos y fechas.

/// Abre una hoja inferior de Finanzas.
///
/// La hoja cuelga del Navigator y no hereda el acento del modulo: se vuelve a
/// declarar, igual que en los formularios.
Future<void> abrirHojaFinanzas(BuildContext context, WidgetBuilder contenido) {
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
    builder: (context) => Acento.modulo('finanzas', contenido),
  );
}

/// El margen de una hoja, con lugar para el teclado cuando se abre.
EdgeInsets margenHoja(BuildContext context) => EdgeInsets.fromLTRB(
  Dimen.espacio4,
  0,
  Dimen.espacio4,
  MediaQuery.viewInsetsOf(context).bottom + Dimen.espacio5,
);

/// Dinero: como mucho dos decimales.
final soloMonto = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

/// El titulo de una hoja, con una linea de apoyo opcional debajo.
class TituloHoja extends StatelessWidget {
  const TituloHoja(this.titulo, {super.key, this.apoyo});

  final String titulo;
  final String? apoyo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        if (apoyo != null) ...[
          const SizedBox(height: Dimen.espacio1),
          Text(
            apoyo!,
            style: const TextStyle(fontSize: 13, color: Colores.tintaSuave),
          ),
        ],
        const SizedBox(height: Dimen.espacio4),
      ],
    );
  }
}

String fechaCorta(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

String fechaHora(DateTime f) =>
    '${fechaCorta(f)} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
