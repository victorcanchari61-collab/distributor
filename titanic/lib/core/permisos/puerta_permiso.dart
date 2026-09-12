import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../compartido/widgets/app_alerta.dart';
import '../../compartido/widgets/app_boton.dart';
import '../../compartido/widgets/app_shell.dart';
import '../navegacion/menu.dart';
import '../red/excepciones.dart';
import '../tema/colores.dart';
import '../tema/dimensiones.dart';
import 'permisos.dart';
import 'solicitud_api.dart';

/// Deja pasar a una pantalla solo si el rol la tiene concedida.
///
/// El menú ya esconde lo que no se puede abrir, pero una ruta se escribe a mano
/// y se comparte por chat: sin esto, pegar un enlace saltaría el filtro. No
/// hace falta decirle qué submódulo proteger — lo deduce de la ruta actual, así
/// que no hay dos sitios donde equivocarse.
class PuertaPermiso extends ConsumerWidget {
  const PuertaPermiso({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruta = GoRouterState.of(context).matchedLocation;
    final item = resolverRuta(ruta).item;

    // Una ruta que no está en el menú no se protege: no hay submódulo al que
    // atarla, y bloquearla dejaría la app sin salida.
    if (item == null) return child;

    final permisos = ref.watch(misPermisosProvider);

    // Mientras cargan no se decide: pintar "sin acceso" un instante y luego la
    // pantalla se lee como un fallo.
    if (permisos.valueOrNull == null) {
      return const AppShell(
        titulo: '',
        rutaActual: '/',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (puedeVer(ref, item.id)) return child;

    return _SinAcceso(titulo: item.titulo, submodulo: item.id);
  }
}

/// Se llegó a una pantalla que el rol no tiene concedida.
///
/// Lleva el botón para pedirla porque entrar es lo único que no puede ofrecerse
/// solo: aquí se sabe con certeza que la persona quería entrar.
class _SinAcceso extends ConsumerStatefulWidget {
  const _SinAcceso({required this.titulo, required this.submodulo});

  final String titulo;
  final String submodulo;

  @override
  ConsumerState<_SinAcceso> createState() => _SinAccesoState();
}

class _SinAccesoState extends ConsumerState<_SinAcceso> {
  bool _enviando = false;
  bool _pedido = false;
  String? _error;

  Future<void> _pedir() async {
    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      await ref.read(solicitudApiProvider).solicitar(
        submodulo: widget.submodulo,
        accion: Accion.ver,
      );
      setState(() => _pedido = true);
    } on ApiExcepcion catch (e) {
      setState(() => _error = e.texto);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      titulo: widget.titulo,
      rutaActual: '/',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Dimen.espacio5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40, color: Colores.tintaTenue),
              const SizedBox(height: Dimen.espacio3),
              const Text(
                'No tienes acceso a esta pantalla',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colores.tinta,
                ),
              ),
              const SizedBox(height: Dimen.espacio2),
              const Text(
                'Tu rol no la incluye. Si necesitas entrar, pídeselo a un administrador.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
              ),
              const SizedBox(height: Dimen.espacio4),

              if (_error != null) ...[
                AppAlerta(_error!),
                const SizedBox(height: Dimen.espacio3),
              ],

              if (_pedido)
                const Text(
                  'Listo, un administrador lo verá en su bandeja.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colores.exito,
                  ),
                )
              else
                AppBoton(
                  texto: 'Pedir acceso',
                  cargando: _enviando,
                  expandido: false,
                  onPressed: _pedir,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
