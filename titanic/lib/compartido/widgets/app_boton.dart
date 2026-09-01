import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

enum BotonVariante { primario, secundario, texto }

enum BotonTam { sm, md, lg }

/// Boton del sistema.
///
/// Mismas variantes y tamanos que el del panel web, para que un cambio de
/// diseno se piense una sola vez. Muestra su propio spinner cuando `cargando`.
class AppBoton extends StatelessWidget {
  const AppBoton({
    super.key,
    required this.texto,
    this.onPressed,
    this.variante = BotonVariante.primario,
    this.tam = BotonTam.lg,
    this.icono,
    this.iconoDerecha,
    this.cargando = false,
    this.expandido = true,
  });

  final String texto;
  final VoidCallback? onPressed;
  final BotonVariante variante;
  final BotonTam tam;
  final IconData? icono;
  final IconData? iconoDerecha;
  final bool cargando;
  final bool expandido;

  double get _alto => switch (tam) {
        BotonTam.sm => Dimen.campoSm,
        BotonTam.md => Dimen.campoMd,
        BotonTam.lg => Dimen.campoLg,
      };

  @override
  Widget build(BuildContext context) {
    // Con el boton cargando se ignora el toque: evita enviar dos veces.
    final accion = cargando ? null : onPressed;

    final contenido = Row(
      mainAxisSize: expandido ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (cargando)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        else if (icono != null)
          Icon(icono, size: 18),
        if (cargando || icono != null) const SizedBox(width: Dimen.espacio2),
        Text(texto),
        if (iconoDerecha != null && !cargando) ...[
          const SizedBox(width: Dimen.espacio2),
          Icon(iconoDerecha, size: 18),
        ],
      ],
    );

    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimen.radioCampo));
    final tamano = expandido ? Size.fromHeight(_alto) : Size(0, _alto);

    return switch (variante) {
      BotonVariante.primario => FilledButton(
          onPressed: accion,
          style: FilledButton.styleFrom(minimumSize: tamano, shape: forma),
          child: contenido,
        ),
      BotonVariante.secundario => OutlinedButton(
          onPressed: accion,
          style: OutlinedButton.styleFrom(minimumSize: tamano, shape: forma),
          child: contenido,
        ),
      BotonVariante.texto => TextButton(
          onPressed: accion,
          style: TextButton.styleFrom(
            minimumSize: Size(0, _alto),
            foregroundColor: Colores.marca,
          ),
          child: contenido,
        ),
    };
  }
}
