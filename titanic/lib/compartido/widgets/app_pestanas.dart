import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Una pestaña: su valor, el texto y, si se quiere, un ícono y cuántos
/// registros tiene.
class Pestana<T> {
  const Pestana(this.valor, this.texto, {this.icono, this.contador});

  final T valor;
  final String texto;
  final IconData? icono;

  /// El número al costado, como en el panel web: cuántos registros tiene.
  final int? contador;
}

/// Las pestañas de una vista, iguales a las del panel web (`Tabs`).
///
/// Se usan cuando varias tablas pequeñas pertenecen al mismo tema y no merecen
/// entrada propia en el menú: las categorías, marcas y unidades viven dentro de
/// Productos; la Bóveda, dentro de Cajas. Se deslizan de lado cuando no entran
/// todas en el ancho del teléfono.
///
/// Van en el hueco `pestanas` de `AppListaPagina`, arriba de todo, en el mismo
/// lugar que en la web.
class AppPestanas<T> extends StatelessWidget {
  const AppPestanas({
    super.key,
    required this.pestanas,
    required this.activa,
    required this.onCambio,
  });

  final List<Pestana<T>> pestanas;
  final T activa;
  final ValueChanged<T> onCambio;

  @override
  Widget build(BuildContext context) {
    final acento = Acento.de(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colores.linea)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio3),
        child: Row(
          children: [
            for (final p in pestanas)
              _Pestana(
                pestana: p,
                activa: p.valor == activa,
                acento: acento,
                onTap: () {
                  if (p.valor != activa) onCambio(p.valor);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Pestana<T> extends StatelessWidget {
  const _Pestana({
    required this.pestana,
    required this.activa,
    required this.acento,
    required this.onTap,
  });

  final Pestana<T> pestana;
  final bool activa;
  final Color acento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = activa ? acento : Colores.tintaSuave;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimen.espacio3,
          vertical: 11,
        ),
        // La línea inferior marca la activa sin mover el texto.
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: activa ? acento : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pestana.icono != null) ...[
              Icon(pestana.icono, size: 17, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              pestana.texto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                color: activa ? acento : Colores.tintaSuave,
              ),
            ),
            if (pestana.contador != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: activa
                      ? acento.withValues(alpha: 0.12)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${pestana.contador}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: activa ? acento : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
