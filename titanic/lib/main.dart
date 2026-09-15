import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/entorno.dart';
import 'core/red/tiempo_real_provider.dart';
import 'core/router/router.dart';
import 'core/tema/tema.dart';

void main() {
  runApp(const ProviderScope(child: TitanicApp()));
}

class TitanicApp extends ConsumerWidget {
  const TitanicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // El vigilante envuelve TODA la app y no una pantalla: la conexion y los
    // permisos tienen que vivir tanto como la sesion, no tanto como la vista
    // que este abierta.
    return VigilanteDeSesion(
      child: MaterialApp.router(
        title: Entorno.nombreApp,
        debugShowCheckedModeBanner: false,
        theme: Tema.claro(),
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
