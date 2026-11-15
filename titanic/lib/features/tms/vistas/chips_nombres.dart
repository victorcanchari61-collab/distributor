import 'package:flutter/material.dart';

import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';

/// Por número cuando lo son ("2" antes que "10"), y por nombre si no: la misma
/// regla que el panel web para los mercados de una ruta y las rutas de un
/// mercado.
List<String> ordenarNombres(Iterable<String> nombres) =>
    [...nombres]..sort(_compararNatural);

int _compararNatural(String a, String b) {
  final trozos = RegExp(r'\d+|\D+');
  final ta = trozos.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final tb = trozos.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < ta.length && i < tb.length; i++) {
    final na = int.tryParse(ta[i]);
    final nb = int.tryParse(tb[i]);
    final c = na != null && nb != null ? na.compareTo(nb) : ta[i].compareTo(tb[i]);
    if (c != 0) return c;
  }
  return ta.length.compareTo(tb.length);
}

/// Nombres en chips chicos: los primeros [maximo] y un "+N" con el resto, para
/// que una ruta con veinte mercados no haga la tarjeta altísima.
class ChipsNombres extends StatelessWidget {
  const ChipsNombres(this.nombres, {super.key, this.maximo = 4});

  final List<String> nombres;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    final todos = ordenarNombres(nombres);
    final vistos = todos.take(maximo).toList();
    final resto = todos.length - vistos.length;
    final acento = Acento.de(context);

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final n in vistos) _chip(n, Colores.linea, Colores.tinta, FontWeight.w500),
        if (resto > 0)
          _chip('+$resto', acento.withValues(alpha: 0.12), acento, FontWeight.w700),
      ],
    );
  }

  Widget _chip(String texto, Color fondo, Color tinta, FontWeight peso) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
    child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: peso, color: tinta)),
  );
}
