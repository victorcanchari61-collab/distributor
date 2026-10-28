import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Una acción de la PANTALLA entera: crear, importar, descargar la plantilla,
/// exportar.
///
/// No es lo mismo que las acciones de un registro (ver, editar, anular,
/// eliminar), que van como iconos dentro de cada tarjeta. En la web esas de la
/// pantalla están en la barra de arriba de la tabla; en el teléfono no caben ahí
/// y van juntas en un solo botón flotante.
///
/// Quien arma la lista decide qué acciones entran: la que el usuario no puede
/// hacer por permiso simplemente no se agrega.
class AccionGlobal {
  const AccionGlobal({
    required this.etiqueta,
    required this.icono,
    required this.onTap,
    this.color = Colores.marca,
  });

  final String etiqueta;
  final IconData icono;
  final VoidCallback onTap;

  /// Cada acción tiene su color para reconocerla sin leer: crear es verde,
  /// exportar turquesa, subir naranja.
  final Color color;

  /// Los colores de las acciones de siempre, para que en todas las pantallas
  /// crear sea verde y exportar turquesa.
  static const verde = Colores.exito;
  static const azul = Color(0xFF0284C7);
  static const naranja = Color(0xFFEA580C);
  static const turquesa = Color(0xFF0D9488);
  static const violeta = Color(0xFF7C3AED);
  static const rojo = Color(0xFFDC2626);
}

/// El botón flotante de la pantalla.
///
/// Con una sola acción es un botón extendido con su etiqueta, como siempre.
/// Con varias es un botón circular "Acciones" que abre el abanico: la lista de
/// abajo se oscurece, las acciones salen en arco desde el botón, cada una con
/// su etiqueta y su color, y el botón se vuelve una X. Tocar fuera o la X lo
/// cierra.
class AppAccionesFlotantes extends StatelessWidget {
  const AppAccionesFlotantes({
    super.key,
    required this.acciones,
    this.colorUnica,
  });

  final List<AccionGlobal> acciones;

  /// El color del botón: el del módulo.
  final Color? colorUnica;

  @override
  Widget build(BuildContext context) {
    if (acciones.isEmpty) return const SizedBox.shrink();

    if (acciones.length == 1) {
      final unica = acciones.first;
      return FloatingActionButton.extended(
        onPressed: unica.onTap,
        backgroundColor: colorUnica ?? unica.color,
        foregroundColor: Colors.white,
        icon: Icon(unica.icono),
        label: Text(unica.etiqueta),
      );
    }

    return _BotonCircular(
      color: colorUnica ?? Colores.marca,
      icono: Icons.apps,
      onTap: () => _abrir(context),
    );
  }

  void _abrir(BuildContext context) {
    final color = colorUnica ?? Colores.marca;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar acciones',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (contexto, animacion, _) =>
          _Abanico(acciones: acciones, color: color, animacion: animacion),
    );
  }
}

/// El lado del botón circular: el del cerrado y el del abierto son iguales
/// para que la X quede exactamente sobre el botón que se tocó.
const double _lado = 72;

/// El botón redondo con su icono y la palabra "Acciones" debajo.
class _BotonCircular extends StatelessWidget {
  const _BotonCircular({
    required this.color,
    required this.icono,
    required this.onTap,
  });

  final Color color;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Acciones',
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 6,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: _lado,
            height: _lado,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, color: Colors.white, size: 26),
                const SizedBox(height: 2),
                const Text(
                  'Acciones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Abanico extends StatelessWidget {
  const _Abanico({
    required this.acciones,
    required this.color,
    required this.animacion,
  });

  final List<AccionGlobal> acciones;
  final Color color;
  final Animation<double> animacion;

  /// El radio del arco más chico: con pocas acciones no hace falta más.
  static const double _radioMinimo = 110;

  /// Lo que separa los centros de dos acciones vecinas, para que no se pisen.
  static const double _separacion = 64;

  @override
  Widget build(BuildContext context) {
    final bajo = MediaQuery.paddingOf(context).bottom;
    final n = acciones.length;
    final t = CurvedAnimation(parent: animacion, curve: Curves.easeOutBack);

    // El centro del botón circular: 16 de cada borde más su radio.
    const borde = Dimen.espacio4;
    const radio = _lado / 2;
    const icono = 48.0;

    // Las acciones van sobre un cuarto de círculo con centro en el botón: la
    // primera justo encima y la última justo a su izquierda, a su misma altura.
    // El radio crece lo justo para que, repartidas en ese cuarto, queden a
    // `_separacion` unas de otras.
    final paso = n > 1 ? (math.pi / 2) / (n - 1) : 0.0;
    final radioArco = n > 1
        ? math.max(_radioMinimo, _separacion / (2 * math.sin(paso / 2)))
        : _radioMinimo;

    // Arriba, donde el arco es casi horizontal, dos acciones vecinas quedan a
    // pocos píxeles de altura y la etiqueta de una taparía a la otra: esa
    // etiqueta sube lo que falte para quedar libre.
    const altoEtiqueta = 46.0;
    double alto(int i) => radioArco * math.cos(paso * i);
    double elevacion(int i) =>
        i >= n - 1 ? 0 : math.max(0, altoEtiqueta - (alto(i) - alto(i + 1)));

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // La primera de la lista es la principal: va arriba del botón.
          for (var i = 0; i < n; i++)
            AnimatedBuilder(
              animation: t,
              builder: (context, hijo) {
                // 0 = justo arriba, 90 grados = justo a la izquierda.
                final angulo = paso * i;
                final avance = t.value.clamp(0.0, 1.2);
                final r = radioArco * avance;

                final derecha =
                    borde + radio - icono / 2 + r * math.sin(angulo);

                return Positioned(
                  right: derecha,
                  bottom:
                      bajo + borde + radio - icono / 2 + r * math.cos(angulo),
                  // En un teléfono angosto la etiqueta no puede pasar del borde
                  // izquierdo: se acorta con puntos suspensivos.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.max(
                        icono,
                        MediaQuery.sizeOf(context).width - derecha - 8,
                      ),
                    ),
                    child: Opacity(
                      opacity: animacion.value.clamp(0.0, 1.0),
                      child: hijo,
                    ),
                  ),
                );
              },
              child: _Fila(
                accion: acciones[i],
                elevacionEtiqueta: elevacion(i),
                alTocar: () {
                  Navigator.of(context).pop();
                  acciones[i].onTap();
                },
              ),
            ),

          Positioned(
            right: borde,
            bottom: bajo + borde,
            child: _BotonCircular(
              color: Colores.navy,
              icono: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.accion,
    required this.alTocar,
    this.elevacionEtiqueta = 0,
  });

  final AccionGlobal accion;

  /// Cuánto sube la etiqueta respecto al icono, para no tapar a la vecina.
  final double elevacionEtiqueta;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: accion.etiqueta,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: alTocar,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Transform.translate(
                offset: Offset(0, -elevacionEtiqueta),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimen.espacio3,
                    vertical: Dimen.espacio2,
                  ),
                  decoration: BoxDecoration(
                    color: Colores.tinta.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // Siempre en una sola fila: la letra es chica y, si aun así
                  // no cabe en un teléfono angosto, se encoge hasta entrar.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      accion.etiqueta,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: Color.lerp(accion.color, Colors.white, 0.65),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Dimen.espacio3),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accion.color,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(accion.icono, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
