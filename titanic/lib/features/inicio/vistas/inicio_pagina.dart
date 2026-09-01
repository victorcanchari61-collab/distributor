import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../compartido/widgets/app_shell.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../auth/estado/auth_controlador.dart';

/// Pantalla tras iniciar sesion: quien entro y accesos a los modulos.
class InicioPagina extends ConsumerWidget {
  const InicioPagina({super.key});

  static const ruta = '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;

    return AppShell(
      titulo: 'Inicio',
      rutaActual: ruta,
      child: ListView(
        padding: const EdgeInsets.all(Dimen.espacio4),
        children: [
          _Bienvenida(
            nombre: usuario?.nombre ?? '',
            rol: usuario?.rol ?? '',
            inicial: usuario?.inicial ?? '?',
          ),
          const SizedBox(height: Dimen.espacio5),

          const Text(
            'Módulos',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Dimen.espacio3),

          // Accesos directos: el menu lateral sirve para navegar, pero al abrir
          // la app conviene ver de una lo que se usa a diario.
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Dimen.espacio3,
            crossAxisSpacing: Dimen.espacio3,
            childAspectRatio: 1.5,
            children: [
              for (final grupo in menuGrupos)
                _TarjetaModulo(
                  grupo: grupo,
                  onTap: () => context.go(grupo.items.first.ruta),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  const _Bienvenida({required this.nombre, required this.rol, required this.inicial});

  final String nombre;
  final String rol;
  final String inicial;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimen.espacio4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colores.marca,
              child: Text(
                inicial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: Dimen.espacio3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hola,',
                    style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
                  ),
                  Text(
                    nombre,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  if (rol.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colores.marcaSuave,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        rol,
                        style: const TextStyle(
                          fontSize: 11,
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
      ),
    );
  }
}

class _TarjetaModulo extends StatelessWidget {
  const _TarjetaModulo({required this.grupo, required this.onTap});

  final MenuGrupo grupo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimen.radioPanel),
      child: Container(
        padding: const EdgeInsets.all(Dimen.espacio4),
        decoration: BoxDecoration(
          color: Colores.superficie,
          border: Border.all(color: Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioPanel),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: grupo.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Dimen.radioCampo),
              ),
              child: Icon(grupo.icono, size: 20, color: grupo.color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grupo.titulo,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${grupo.items.length} vistas',
                  style: const TextStyle(fontSize: 11, color: Colores.tintaSuave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
