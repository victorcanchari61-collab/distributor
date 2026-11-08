import 'package:flutter/material.dart';

import '../../core/permisos/sin_permiso.dart';
import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import 'app_sin_permiso.dart';

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
    this.color,
    this.sinPermiso = false,
  });

  final String texto;
  final VoidCallback? onPressed;
  final BotonVariante variante;
  final BotonTam tam;
  final IconData? icono;
  final IconData? iconoDerecha;
  final bool cargando;
  final bool expandido;

  /// Color de fondo propio, para acciones con carga semantica: el rojo de
  /// eliminar o el ambar de desactivar. Null toma el acento del modulo en el
  /// que se este, igual que en el panel web.
  final Color? color;

  /// La persona no tiene permiso para esta acción: el botón se ve en gris, con
  /// la ayuda "No tienes permiso para esta acción", y al tocarlo lo avisa en
  /// vez de ejecutar nada. Igual que `sinPermiso` del Button del panel web.
  /// También se activa si [onPressed] es la marca `accionSinPermiso`.
  final bool sinPermiso;

  double get _alto => switch (tam) {
    BotonTam.sm => Dimen.campoSm,
    BotonTam.md => Dimen.campoMd,
    BotonTam.lg => Dimen.campoLg,
  };

  /// El botón sin permiso: gris y apagado, pero tocable para poder avisar.
  Widget _gris(
    VoidCallback? accion,
    Widget contenido,
    OutlinedBorder forma,
    Size tamano,
  ) {
    const fondo = Color(0xFFE2E8F0);
    const letra = Colores.tintaTenue;

    return switch (variante) {
      BotonVariante.primario => FilledButton(
        onPressed: accion,
        style: FilledButton.styleFrom(
          minimumSize: tamano,
          shape: forma,
          backgroundColor: fondo,
          foregroundColor: letra,
        ),
        child: contenido,
      ),
      BotonVariante.secundario => OutlinedButton(
        onPressed: accion,
        style: OutlinedButton.styleFrom(
          minimumSize: tamano,
          shape: forma,
          foregroundColor: letra,
          side: const BorderSide(color: fondo),
        ),
        child: contenido,
      ),
      BotonVariante.texto => TextButton(
        onPressed: accion,
        style: TextButton.styleFrom(
          minimumSize: Size(0, _alto),
          foregroundColor: letra,
        ),
        child: contenido,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final sinPermisoFinal = sinPermiso || esSinPermiso(onPressed);

    // Con el boton cargando se ignora el toque: evita enviar dos veces. Sin
    // permiso el toque SI llega, pero solo para avisar.
    final accion = sinPermisoFinal
        ? () => avisarSinPermiso(context)
        : (cargando ? null : onPressed);

    final contenido = Row(
      mainAxisSize: expandido ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (cargando)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        else if (icono != null)
          Icon(icono, size: 18),
        if (cargando || icono != null) const SizedBox(width: Dimen.espacio2),
        // Flexible: en un boton angosto el texto se recorta en vez de
        // desbordar la fila.
        Flexible(
          child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (iconoDerecha != null && !cargando) ...[
          const SizedBox(width: Dimen.espacio2),
          Icon(iconoDerecha, size: 18),
        ],
      ],
    );

    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
    );
    final tamano = expandido ? Size.fromHeight(_alto) : Size(0, _alto);

    if (sinPermisoFinal) {
      return Tooltip(
        message: avisoSinPermiso,
        child: _gris(accion, contenido, forma, tamano),
      );
    }

    return switch (variante) {
      BotonVariante.primario => FilledButton(
        onPressed: accion,
        style: FilledButton.styleFrom(
          minimumSize: tamano,
          shape: forma,
          backgroundColor: color ?? Acento.de(context),
          // El deshabilitado tambien: si no, lo hereda del tema, que lo tiene
          // fijado al azul de marca. Un boton apagado se pasa mas tiempo a la
          // vista que uno activo — el de "Agregar producto" esta apagado hasta
          // que se elige algo — asi que era justo el que delataba el color.
          disabledBackgroundColor: (color ?? Acento.de(context)).withValues(
            alpha: 0.5,
          ),
        ),
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
          foregroundColor: color ?? Acento.de(context),
        ),
        child: contenido,
      ),
    };
  }
}
