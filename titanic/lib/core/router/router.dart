import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../compartido/widgets/app_shell.dart';
import '../../features/auth/estado/auth_controlador.dart';
import '../../features/config/vistas/empresas_pagina.dart';
import '../../features/config/vistas/roles_pagina.dart';
import '../../features/config/vistas/usuarios_pagina.dart';
import '../../features/inicio/vistas/inicio_pagina.dart';
import '../../features/inicio/vistas/pendiente_pagina.dart';
import '../../features/maestros/vistas/clientes_pagina.dart';
import '../../features/maestros/vistas/proveedores_pagina.dart';
import '../navegacion/menu.dart';
import 'puerta_sesion.dart';

/// Rutas de la app.
///
/// La raiz la resuelve PuertaSesion segun el estado de la sesion, y el
/// `redirect` protege el resto: sin sesion, cualquier ruta vuelve a la raiz.
///
/// Las rutas de los modulos se generan desde el menu: agregar una entrada en
/// `menu.dart` crea su ruta sin tocar este archivo.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: InicioPagina.ruta,
    redirect: (context, estado) {
      final sesion = ref.read(authProvider).estado;
      final enRaiz = estado.matchedLocation == InicioPagina.ruta;

      // La raiz se resuelve sola con PuertaSesion, que observa el estado: no se
      // redirige desde aqui para no depender de cuando termine la lectura del
      // almacen. El resto de rutas si se protege.
      if (enRaiz || sesion == EstadoSesion.cargando) return null;

      return sesion == EstadoSesion.invitado ? InicioPagina.ruta : null;
    },
    refreshListenable: _EscuchaAuth(ref),
    errorBuilder: (context, estado) => const AppShell(
      titulo: 'No encontrado',
      rutaActual: InicioPagina.ruta,
      child: PendientePagina(titulo: 'Esa pantalla no existe'),
    ),
    routes: [
      // La raiz muestra carga, login o inicio segun el estado de la sesion.
      GoRoute(
        path: InicioPagina.ruta,
        builder: (context, estado) => const PuertaSesion(),
      ),

      // Una ruta por cada vista del menu, generadas de la misma fuente que lo
      // pinta: el menu y la navegacion nunca se desincronizan.
      // Pantallas ya construidas.
      GoRoute(
        path: ClientesPagina.ruta,
        builder: (context, estado) => const ClientesPagina(),
      ),
      GoRoute(
        path: ProveedoresPagina.ruta,
        builder: (context, estado) => const ProveedoresPagina(),
      ),
      GoRoute(
        path: UsuariosPagina.ruta,
        builder: (context, estado) => const UsuariosPagina(),
      ),
      GoRoute(
        path: RolesPagina.ruta,
        builder: (context, estado) => const RolesPagina(),
      ),
      GoRoute(
        path: EmpresasPagina.ruta,
        builder: (context, estado) => const EmpresasPagina(),
      ),

      for (final grupo in menuGrupos)
        for (final item in grupo.items)
          // Las que ya tienen pantalla propia se declaran arriba.
          if (item.ruta != ClientesPagina.ruta &&
              item.ruta != ProveedoresPagina.ruta)
            GoRoute(
              path: item.ruta,
              builder: (context, estado) => AppShell(
                titulo: item.titulo,
                subtitulo: grupo.titulo,
                acentado: grupo.color,
                rutaActual: item.ruta,
                child: PendientePagina(
                  titulo: item.titulo,
                  modulo: grupo.titulo,
                  color: grupo.color,
                ),
              ),
            ),
    ],
  );
});

/// Vuelve a evaluar las rutas cuando cambia el estado de la sesion.
class _EscuchaAuth extends ChangeNotifier {
  _EscuchaAuth(Ref ref) {
    ref.listen(authProvider, (anterior, actual) {
      if (anterior?.estado != actual.estado) notifyListeners();
    });
  }
}
