import 'package:flutter/material.dart';

import '../../core/permisos/sin_permiso.dart';
import '../../core/tema/colores.dart';
import 'app_aviso.dart';

/// Qué hace el botón. Cada uno tiene SU color, igual en toda la app y en el
/// panel web (`RowAction`): eliminar es rojo en Usuarios, en TMS y en
/// Inventario, así se reconoce sin leer.
enum TonoAccion {
  /// Ver el detalle: azul.
  ver(Color(0xFF0284C7), Color(0xFF075985)),

  /// Editar: cian.
  editar(Color(0xFF0891B2), Color(0xFF155E75)),

  /// Anular / eliminar: rosa fuerte.
  peligro(Color(0xFFE11D48), Color(0xFF9F1239)),

  /// Confirmar / recibir / activar / convertir: verde.
  exito(Color(0xFF059669), Color(0xFF065F46)),

  /// Desactivar, devolver, no entregado y otras intermedias: naranja.
  aviso(Color(0xFFD97706), Color(0xFF92400E)),

  /// Historial y lo que no encaja en otro: gris pizarra.
  neutral(Color(0xFF64748B), Color(0xFF334155)),

  /// PDF, imprimir y documentos para descargar: el rojo clásico del PDF.
  documento(Color(0xFFDC2626), Color(0xFF991B1B));

  const TonoAccion(this.fondo, this.base);

  final Color fondo;

  /// La franja más oscura de abajo que da el efecto 3D.
  final Color base;
}

/// Botón de una acción de fila (en la tarjeta de un registro): una píldora de
/// color con el ícono en blanco y una base más oscura debajo, que se hunde al
/// presionarla. Es el mismo botón que la columna Acciones del panel web.
///
/// Como en el web, el botón que no aplica NO desaparece: se ve en gris y, al
/// tocarlo, dice por qué ([motivo]). Así las tarjetas tienen siempre los
/// mismos botones en el mismo lugar. Sin permiso (ver `permitir`) también se ve
/// en gris y avisa que falta el permiso.
class AppBotonFila extends StatefulWidget {
  const AppBotonFila({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.tono,
    this.onPressed,
    this.motivo,
  });

  final IconData icono;

  /// Lo que hace, para el tooltip y la lectura en voz alta.
  final String etiqueta;
  final TonoAccion tono;

  /// Null: no aplica a este registro (se ve en gris).
  final VoidCallback? onPressed;

  /// Por qué no aplica ("Ya está confirmado"). Se muestra al tocarlo en gris.
  final String? motivo;

  @override
  State<AppBotonFila> createState() => _AppBotonFilaState();
}

class _AppBotonFilaState extends State<AppBotonFila> {
  /// Presionado: el botón baja hasta tocar su base.
  bool _abajo = false;

  static const _duracion = Duration(milliseconds: 110);
  static const _alto = 30.0;
  static const _ancho = 38.0;
  static const _base = 3.0;

  @override
  Widget build(BuildContext context) {
    final accion = widget.onPressed;
    final sinPermiso = accion != null && esSinPermiso(accion);
    final activo = accion != null && !sinPermiso;

    final fondo = activo ? widget.tono.fondo : const Color(0xFFE2E8F0);
    final hundido = activo && _abajo;

    void alTocar() {
      if (sinPermiso) return avisarSinPermisoBoton(context);
      if (!activo) {
        final motivo = widget.motivo;
        if (motivo != null && motivo.isNotEmpty) Aviso.de(context).mostrar(motivo);
        return;
      }
      accion();
    }

    return Tooltip(
      message: sinPermiso
          ? avisoSinPermiso
          : (!activo && widget.motivo != null)
          ? widget.motivo!
          : widget.etiqueta,
      child: Semantics(
        button: true,
        enabled: activo,
        label: widget.etiqueta,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: activo ? (_) => setState(() => _abajo = true) : null,
          onTapUp: activo ? (_) => setState(() => _abajo = false) : null,
          onTapCancel: activo ? () => setState(() => _abajo = false) : null,
          onTap: alTocar,
          child: SizedBox(
            width: _ancho,
            height: _alto + _base,
            child: Stack(
              children: [
                // La base: la parte más oscura que asoma debajo.
                if (activo)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _alto,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.tono.base,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                // El botón: al presionar baja hasta la base.
                AnimatedPositioned(
                  duration: _duracion,
                  curve: Curves.easeOut,
                  left: 0,
                  right: 0,
                  top: hundido || !activo ? _base : 0,
                  height: _alto,
                  child: AnimatedContainer(
                    duration: _duracion,
                    decoration: BoxDecoration(
                      color: fondo,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icono,
                      size: 17,
                      color: activo ? Colors.white : Colores.tintaTenue,
                    ),
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

/// Aviso de falta de permiso desde un botón de fila.
void avisarSinPermisoBoton(BuildContext context) =>
    Aviso.de(context).error(avisoSinPermiso);
