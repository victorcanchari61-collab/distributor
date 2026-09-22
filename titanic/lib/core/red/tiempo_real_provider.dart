import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/estado/auth_controlador.dart';
import '../permisos/permisos.dart';
import 'puente_tiempo_real.dart';
import 'tiempo_real.dart';

/// La conexión viva, una sola para toda la app.
final tiempoRealProvider = Provider<TiempoReal>((ref) {
  final tiempoReal = TiempoReal();
  ref.onDispose(tiempoReal.dispose);
  return tiempoReal;
});

/// Los cambios de unos módulos concretos, para que una pantalla se refresque.
final cambiosProvider = StreamProvider.family<CambioEvento, String>((
  ref,
  modulos,
) {
  final tiempoReal = ref.watch(tiempoRealProvider);
  unawaited(tiempoReal.conectar());
  return tiempoReal.de(modulos.split(','));
});

/// Refresca lo que esta pantalla muestra cuando cambia en otro lado.
///
/// Se usa dentro del build de una pantalla:
///
/// ```dart
/// escucharCambios(ref, ['productos'], () => ref.invalidate(productosProvider));
/// ```
void escucharCambios(
  WidgetRef ref,
  List<String> modulos,
  VoidCallback alCambiar,
) {
  ref.listen(cambiosProvider(modulos.join(',')), (_, siguiente) {
    if (siguiente.hasValue) alCambiar();
  });
}

/// Mantiene los permisos al día sin que nadie tenga que salir y volver a entrar.
///
/// Dos caminos, porque ninguno alcanza solo:
///
///   - El aviso del servidor, que llega al instante mientras la app está a la
///     vista. Es el caso que importa: al vendedor le conceden un permiso y el
///     menú le aparece sin hacer nada.
///   - La revisión al volver del segundo plano, porque Android corta los
///     sockets de una app que no se está mirando y el aviso de ese rato se
///     perdió. Al volver se pregunta de nuevo y se reconecta.
///
/// Va colgado de la raíz de la app: es lo único que vive tanto como la sesión.
class VigilanteDeSesion extends ConsumerStatefulWidget {
  const VigilanteDeSesion({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VigilanteDeSesion> createState() => _VigilanteDeSesionState();
}

class _VigilanteDeSesionState extends ConsumerState<VigilanteDeSesion>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado != AppLifecycleState.resumed) return;
    if (ref.read(authProvider).usuario == null) return;

    // Al volver: reconectar y volver a preguntar qué puede hacer esta persona.
    // Si le quitaron un permiso mientras no miraba, el menú deja de ofrecerlo.
    unawaited(ref.read(tiempoRealProvider).asegurarConexion());
    ref.invalidate(misPermisosProvider);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;

    // La conexión sigue a la sesión: se abre al entrar y se cierra al salir,
    // para no seguir escuchando lo de alguien que ya no está.
    ref.listen(authProvider, (antes, ahora) {
      final tiempoReal = ref.read(tiempoRealProvider);
      if (ahora.usuario == null) {
        unawaited(tiempoReal.desconectar());
      } else if (antes?.usuario?.id != ahora.usuario?.id) {
        unawaited(tiempoReal.conectar());
      }
    });

    /*
     * Todo lo que cambie en el servidor, atendido desde un solo sitio.
     *
     * Un permiso concedido redibuja el menu; un precio corregido o un stock
     * que se movio llegan a la pantalla que los este mostrando. El puente
     * decide que volver a pedir segun el modulo, y Riverpod solo dispara las
     * llamadas de lo que alguien tenga abierto.
     */
    if (usuario != null) {
      ref.listen(cambiosProvider(modulosEscuchados.join(',')), (_, siguiente) {
        final evento = siguiente.valueOrNull;
        if (evento != null) refrescarPorCambio(ref, evento.modulo);
      });
    }

    return widget.child;
  }
}
