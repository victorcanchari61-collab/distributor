import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Aviso momentaneo, arriba de la pantalla.
///
/// Reemplaza al SnackBar de Flutter, que sale ABAJO —justo donde estan el
/// teclado y los botones de guardar, asi que tapaba lo que uno acababa de
/// tocar— y siempre del mismo color, sin relacion con el modulo en el que se
/// esta. Es el hermano del toast de la web: mismo sitio y mismo criterio de
/// color.
///
/// Se toma con `Aviso.de(context)` ANTES de un await y se usa despues, igual
/// que se hacia con ScaffoldMessenger: asi no se toca el context de un widget
/// que quiza ya no esta montado.
class Aviso {
  const Aviso._(this._overlay, this._acento);

  final OverlayState _overlay;
  final Color _acento;

  /// El mensajero de esta pantalla, con el color de su modulo ya resuelto.
  static Aviso de(BuildContext context) =>
      Aviso._(Overlay.of(context, rootOverlay: true), Acento.de(context));

  /// Algo salio bien. Toma el color del modulo.
  void mostrar(String mensaje) => _pintar(mensaje, _acento, const Duration(seconds: 3));

  /// Algo fallo. Siempre rojo: el color del modulo dice DONDE estas, no que
  /// algo salio mal, y un error en el rosa de DMS no se lee como error.
  void error(String mensaje) =>
      _pintar(mensaje, Colores.peligro, const Duration(seconds: 5));

  void _pintar(String mensaje, Color color, Duration duracion) {
    late final OverlayEntry entrada;
    entrada = OverlayEntry(
      builder: (context) => _Tarjeta(
        mensaje: mensaje,
        color: color,
        duracion: duracion,
        alCerrar: () {
          if (entrada.mounted) entrada.remove();
        },
      ),
    );
    _overlay.insert(entrada);
  }
}

class _Tarjeta extends StatefulWidget {
  const _Tarjeta({
    required this.mensaje,
    required this.color,
    required this.duracion,
    required this.alCerrar,
  });

  final String mensaje;
  final Color color;
  final Duration duracion;
  final VoidCallback alCerrar;

  @override
  State<_Tarjeta> createState() => _TarjetaState();
}

class _TarjetaState extends State<_Tarjeta> with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void initState() {
    super.initState();
    _control.forward();
    Future.delayed(widget.duracion, _cerrar);
  }

  Future<void> _cerrar() async {
    if (!mounted) return;
    await _control.reverse();
    widget.alCerrar();
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.of(context).padding.top;

    return Positioned(
      top: arriba + Dimen.espacio2,
      left: Dimen.espacio4,
      right: Dimen.espacio4,
      child: FadeTransition(
        opacity: _control,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.3), end: Offset.zero).animate(
            CurvedAnimation(parent: _control, curve: Curves.easeOut),
          ),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              // Un toque lo quita: un aviso nunca debe estorbar.
              onTap: _cerrar,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimen.espacio4,
                  vertical: Dimen.espacio3,
                ),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(Dimen.radioCampo),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  widget.mensaje,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
