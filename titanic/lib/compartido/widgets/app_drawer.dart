import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navegacion/menu.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import '../../features/auth/estado/auth_controlador.dart';
import '../../features/inicio/vistas/inicio_pagina.dart';
import 'app_logo.dart';

/// Menu lateral de la app.
///
/// Equivale al sider del panel web, pero adaptado al telefono: los modulos se
/// despliegan de a uno y cada uno lleva su color, para orientarse por color
/// igual que en el escritorio.
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key, required this.rutaActual});

  final String rutaActual;

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  /// Modulo desplegado. Solo uno a la vez: con todos abiertos habria que
  /// desplazar mucho para llegar al final.
  late String? _abierto = resolverRuta(widget.rutaActual).grupo?.id ?? menuGrupos.first.id;

  void _ir(MenuItem item) {
    Navigator.of(context).pop();
    if (item.ruta != widget.rutaActual) context.go(item.ruta);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;

    return Drawer(
      backgroundColor: Colores.superficie,
      child: SafeArea(
        child: Column(
          children: [
            _Cabecera(
              nombre: usuario?.nombre ?? '',
              email: usuario?.email ?? '',
              rol: usuario?.rol ?? '',
              inicial: usuario?.inicial ?? '?',
            ),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: Dimen.espacio2),
                children: [
                  _ItemSimple(
                    icono: Icons.home_outlined,
                    titulo: 'Inicio',
                    activo: widget.rutaActual == InicioPagina.ruta,
                    color: Colores.marca,
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.rutaActual != InicioPagina.ruta) {
                        context.go(InicioPagina.ruta);
                      }
                    },
                  ),
                  const Divider(indent: Dimen.espacio4, endIndent: Dimen.espacio4),

                  for (final grupo in menuGrupos)
                    _Grupo(
                      grupo: grupo,
                      abierto: _abierto == grupo.id,
                      rutaActual: widget.rutaActual,
                      onAbrir: () => setState(
                        () => _abierto = _abierto == grupo.id ? null : grupo.id,
                      ),
                      onElegir: _ir,
                    ),
                ],
              ),
            ),

            const Divider(height: 1),
            _ItemSimple(
              icono: Icons.logout,
              titulo: 'Cerrar sesión',
              activo: false,
              color: Colores.peligro,
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).salir();
              },
            ),
            const SizedBox(height: Dimen.espacio2),
          ],
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.nombre,
    required this.email,
    required this.rol,
    required this.inicial,
  });

  final String nombre;
  final String email;
  final String rol;
  final String inicial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Dimen.espacio4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppLogo(variante: LogoVariante.marca, tam: 30),
              const SizedBox(width: Dimen.espacio2),
              const Text(
                'Titanic D',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio4),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colores.marca,
                child: Text(
                  inicial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                    ),
                    if (rol.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colores.marcaSuave,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          rol,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colores.marcaHover,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modulo desplegable con sus vistas.
class _Grupo extends StatelessWidget {
  const _Grupo({
    required this.grupo,
    required this.abierto,
    required this.rutaActual,
    required this.onAbrir,
    required this.onElegir,
  });

  final MenuGrupo grupo;
  final bool abierto;
  final String rutaActual;
  final VoidCallback onAbrir;
  final void Function(MenuItem) onElegir;

  @override
  Widget build(BuildContext context) {
    final tieneActiva = grupo.items.any((i) => i.ruta == rutaActual);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onAbrir,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimen.espacio4,
              vertical: Dimen.espacio3,
            ),
            child: Row(
              children: [
                Icon(grupo.icono, size: 20, color: grupo.color),
                const SizedBox(width: Dimen.espacio3),
                Expanded(
                  child: Text(
                    grupo.titulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tieneActiva ? grupo.color : Colores.tinta,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: abierto ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colores.tintaSuave,
                  ),
                ),
              ],
            ),
          ),
        ),

        // La animacion la da AnimatedSize: el contenido crece y encoge sin
        // saltos, igual que el acordeon del panel web.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: abierto
              ? Column(
                  children: [
                    for (final item in grupo.items)
                      _Vista(
                        item: item,
                        color: grupo.color,
                        activo: item.ruta == rutaActual,
                        onTap: () => onElegir(item),
                      ),
                    const SizedBox(height: Dimen.espacio2),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _Vista extends StatelessWidget {
  const _Vista({
    required this.item,
    required this.color,
    required this.activo,
    required this.onTap,
  });

  final MenuItem item;
  final Color color;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: activo ? color.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.only(
          left: Dimen.espacio6,
          right: Dimen.espacio4,
          top: 10,
          bottom: 10,
        ),
        child: Row(
          children: [
            Icon(item.icono, size: 18, color: activo ? color : Colores.tintaSuave),
            const SizedBox(width: Dimen.espacio3),
            Expanded(
              child: Text(
                item.titulo,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w400,
                  color: activo ? color : Colores.tinta,
                ),
              ),
            ),
            // Punto tenue: la vista todavia no existe, igual que en el web.
            if (item.pendiente)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colores.lineaFuerte,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemSimple extends StatelessWidget {
  const _ItemSimple({
    required this.icono,
    required this.titulo,
    required this.activo,
    required this.color,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final bool activo;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: activo ? color.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: Dimen.espacio4,
          vertical: Dimen.espacio3,
        ),
        child: Row(
          children: [
            Icon(icono, size: 20, color: color),
            const SizedBox(width: Dimen.espacio3),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 14,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w600,
                color: activo ? color : Colores.tinta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
