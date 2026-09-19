import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import 'grafico_util.dart';

/// La tarjeta que envuelve cada gráfico del tablero: título, conclusión, y los
/// tres estados que comparten todos — cargando, sin datos y con error.
///
/// Es `Marco` del panel web. Así ningún gráfico decide por su cuenta cómo se ve
/// la espera, y una base sin ventas no deja pantallas a medio pintar.
///
/// El contenido se pasa como función y no como widget ya armado: los datos de
/// un gráfico se calculan recién cuando hay algo que dibujar, no mientras el
/// esqueleto está en pantalla o cuando la lista viene vacía.
class MarcoGrafico extends StatelessWidget {
  const MarcoGrafico({
    super.key,
    required this.titulo,
    required this.contenido,
    this.subtitulo,
    this.enfasis,
    this.sufijo,
    this.cargando = false,
    this.error,
    this.vacio = false,
    this.mensajeVacio = 'Sin datos en este período',
    this.alto = 220,
  });

  final String titulo;

  /// Lo que el gráfico concluye, en una línea: "+12% frente a los 30 días
  /// anteriores". Puede llevar una parte en negrita ([enfasis]) y un cierre
  /// ([sufijo]): "Cierre proyectado **S/ 12,345** · +8% frente al mes pasado".
  final String? subtitulo;
  final String? enfasis;
  final String? sufijo;

  final bool cargando;

  /// El mensaje de por qué no se pudo cargar. Tiene prioridad sobre `vacio`.
  final String? error;

  /// El gráfico no tiene nada que dibujar.
  final bool vacio;
  final String mensajeVacio;

  /// Alto que reservan el esqueleto, el error y el vacío, para que la tarjeta
  /// no salte al cargar.
  final double alto;

  final Widget Function() contenido;

  bool get _tieneSubtitulo =>
      (subtitulo?.isNotEmpty ?? false) ||
      (enfasis?.isNotEmpty ?? false) ||
      (sufijo?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimen.espacio4),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
          if (_tieneSubtitulo) ...[
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colores.tintaSuave,
                ),
                children: [
                  if (subtitulo != null) TextSpan(text: subtitulo),
                  if (enfasis != null)
                    TextSpan(
                      text: enfasis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colores.tinta,
                      ),
                    ),
                  if (sufijo != null) TextSpan(text: sufijo),
                ],
              ),
            ),
          ],
          const SizedBox(height: Dimen.espacio3),
          if (cargando)
            Esqueleto(alto: alto)
          else if (error != null)
            _Error(mensaje: error!, alto: alto)
          else if (vacio)
            _Vacio(mensaje: mensajeVacio, alto: alto)
          else
            contenido(),
        ],
      ),
    );
  }
}

/// El bloque gris que pulsa mientras llegan los datos.
class Esqueleto extends StatefulWidget {
  const Esqueleto({super.key, required this.alto, this.radio = Dimen.radioCampo});

  final double alto;
  final double radio;

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.5).animate(_pulso),
      child: Container(
        height: widget.alto,
        decoration: BoxDecoration(
          color: PaletaDash.fondoSuave,
          borderRadius: BorderRadius.circular(widget.radio),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.alto});

  final String mensaje;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: alto,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colores.peligroSuave,
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Text(
        mensaje,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.mensaje, required this.alto});

  final String mensaje;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: alto,
      width: double.infinity,
      decoration: BoxDecoration(
        color: PaletaDash.fondoSuave,
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart_rounded, size: 24, color: Colores.tintaTenue),
          const SizedBox(height: Dimen.espacio2),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colores.tintaTenue),
          ),
        ],
      ),
    );
  }
}
