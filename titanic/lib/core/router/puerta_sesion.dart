import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/estado/auth_controlador.dart';
import '../../features/auth/vistas/login_pagina.dart';
import '../../features/inicio/vistas/inicio_pagina.dart';
import '../tema/colores.dart';

/// Decide que se ve en la raiz segun el estado de la sesion.
///
/// Observa el estado con `watch` en vez de depender solo del `redirect` del
/// router: si la lectura del almacen termina despues de que el router ya
/// decidio, el redirect no se vuelve a evaluar y la app se queda con el
/// indicador girando. Observando el estado, la pantalla se corrige sola.
class PuertaSesion extends ConsumerWidget {
  const PuertaSesion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(authProvider).estado;

    return switch (sesion) {
      EstadoSesion.cargando => const _Cargando(),
      EstadoSesion.invitado => const LoginPagina(),
      EstadoSesion.autenticado => const InicioPagina(),
    };
  }
}

/// Mientras se lee la sesion guardada en el dispositivo.
class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Colores.superficie,
    body: Center(child: CircularProgressIndicator(color: Colores.marca)),
  );
}
