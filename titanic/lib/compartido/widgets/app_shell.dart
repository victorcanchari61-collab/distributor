import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import 'app_drawer.dart';

/// Armazon de las pantallas internas: barra superior, menu lateral y contenido.
///
/// Toda pantalla dentro de la sesion se monta aqui, asi el menu y la barra se
/// definen una sola vez y no se repiten en cada vista.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.titulo,
    required this.rutaActual,
    required this.child,
    this.subtitulo,
    this.acentado,
    this.acciones,
  });

  final String titulo;

  /// Modulo al que pertenece la vista, en pequeno sobre el titulo.
  final String? subtitulo;

  /// Color del modulo: tine el subtitulo, como en el panel web.
  final Color? acentado;

  final String rutaActual;
  final Widget child;
  final List<Widget>? acciones;

  @override
  Widget build(BuildContext context) {
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
        actions: [...?acciones, const SizedBox(width: Dimen.espacio2)],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: child,
    );
  }
}
