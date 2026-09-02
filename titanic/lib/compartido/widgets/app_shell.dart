import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import '../../features/auth/estado/auth_controlador.dart';
import 'app_drawer.dart';

/// Armazon de las pantallas internas: barra superior, menu lateral y contenido.
///
/// Toda pantalla dentro de la sesion se monta aqui, asi el menu y la barra se
/// definen una sola vez y no se repiten en cada vista.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.titulo,
    required this.rutaActual,
    required this.child,
    this.subtitulo,
    this.acentado,
    this.acciones,
    this.accionFlotante,
  });

  final String titulo;

  /// Modulo al que pertenece la vista, en pequeno sobre el titulo.
  final String? subtitulo;

  /// Color del modulo: tine el subtitulo, como en el panel web.
  final Color? acentado;

  final String rutaActual;
  final Widget child;
  final List<Widget>? acciones;

  /// Boton flotante de la pantalla, normalmente el de crear.
  final Widget? accionFlotante;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;

    return Scaffold(
      drawer: AppDrawer(rutaActual: rutaActual),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subtitulo != null)
              Text(
                subtitulo!.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: acentado ?? Colores.marca,
                ),
              ),
            Text(
              titulo,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          ...?acciones,
          // Quien esta conectado va aqui, no en el menu: se ve siempre, sin
          // tener que abrir el drawer.
          if (usuario != null)
            Padding(
              padding: const EdgeInsets.only(right: Dimen.espacio3),
              child: Tooltip(
                message: '${usuario.nombre}\n${usuario.rol}',
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: Colores.marca,
                  child: Text(
                    usuario.inicial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: child,
      floatingActionButton: accionFlotante,
    );
  }
}
