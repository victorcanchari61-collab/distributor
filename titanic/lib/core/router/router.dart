import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../compartido/widgets/app_shell.dart';
import '../../features/auth/estado/auth_controlador.dart';
import '../../features/compras/vistas/mis_compras_pagina.dart';
import '../../features/compras/vistas/ordenes_compra_pagina.dart';
import '../../features/compras/vistas/recepciones_pagina.dart';
import '../../features/config/vistas/accesos_pagina.dart';
import '../../features/config/vistas/auditoria_pagina.dart';
import '../../features/config/vistas/empresas_pagina.dart';
import '../../features/config/vistas/roles_pagina.dart';
import '../../features/config/vistas/usuarios_pagina.dart';
import '../../features/facturacion/vistas/listas_precios_pagina.dart';
import '../../features/finanzas/vistas/arqueo_diario_pagina.dart';
import '../../features/finanzas/vistas/cuentas_por_cobrar_pagina.dart';
import '../../features/finanzas/vistas/cuentas_por_pagar_pagina.dart';
import '../../features/finanzas/vistas/mis_cobros_pagina.dart';
import '../../features/finanzas/vistas/metodos_pago_pagina.dart';
import '../../features/inicio/vistas/inicio_pagina.dart';
import '../../features/inicio/vistas/pendiente_pagina.dart';
import '../../features/inventario/vistas/ajustes_pagina.dart';
import '../../features/inventario/vistas/almacenes_pagina.dart';
import '../../features/inventario/vistas/conteos_pagina.dart';
import '../../features/inventario/vistas/kardex_pagina.dart';
import '../../features/inventario/vistas/lotes_pagina.dart';
import '../../features/inventario/vistas/prestamos_pagina.dart';
import '../../features/inventario/vistas/stock_pagina.dart';
import '../../features/inventario/vistas/transferencias_pagina.dart';
import '../../features/maestros/vistas/clientes_pagina.dart';
import '../../features/maestros/vistas/productos_pagina.dart';
import '../../features/maestros/vistas/proveedores_pagina.dart';
import '../../features/tms/vistas/mercados_pagina.dart';
import '../../features/tms/vistas/rutas_pagina.dart';
import '../../features/ventas/vistas/notas_venta_pagina.dart';
import '../../features/ventas/vistas/pedidos_pagina.dart';
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
        path: ProductosPagina.ruta,
        builder: (context, estado) => const ProductosPagina(),
      ),
      GoRoute(
        path: AlmacenesPagina.ruta,
        builder: (context, estado) => const AlmacenesPagina(),
      ),
      GoRoute(
        path: StockPagina.ruta,
        builder: (context, estado) => const StockPagina(),
      ),
      GoRoute(
        path: KardexPagina.ruta,
        builder: (context, estado) => const KardexPagina(),
      ),
      GoRoute(
        path: LotesPagina.ruta,
        builder: (context, estado) => const LotesPagina(),
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
      GoRoute(
        path: MetodosPagoPagina.ruta,
        builder: (context, estado) => const MetodosPagoPagina(),
      ),
      GoRoute(
        path: OrdenesCompraPagina.ruta,
        builder: (context, estado) => const OrdenesCompraPagina(),
      ),
      GoRoute(
        path: MisComprasPagina.ruta,
        builder: (context, estado) => const MisComprasPagina(),
      ),
      GoRoute(
        path: RecepcionesPagina.ruta,
        builder: (context, estado) => const RecepcionesPagina(),
      ),
      GoRoute(
        path: AjustesPagina.ruta,
        builder: (context, estado) => const AjustesPagina(),
      ),
      GoRoute(
        path: TransferenciasPagina.ruta,
        builder: (context, estado) => const TransferenciasPagina(),
      ),
      GoRoute(
        path: PrestamosPagina.ruta,
        builder: (context, estado) => const PrestamosPagina(),
      ),
      GoRoute(
        path: ConteosPagina.ruta,
        builder: (context, estado) => const ConteosPagina(),
      ),
      GoRoute(
        path: ListasPreciosPagina.ruta,
        builder: (context, estado) => const ListasPreciosPagina(),
      ),
      GoRoute(
        path: AccesosPagina.ruta,
        builder: (context, estado) => const AccesosPagina(),
      ),
      GoRoute(
        path: AuditoriaPagina.ruta,
        builder: (context, estado) => const AuditoriaPagina(),
      ),
      GoRoute(
        path: PedidosPagina.ruta,
        builder: (context, estado) => const PedidosPagina(),
      ),
      GoRoute(
        path: NotasVentaPagina.ruta,
        builder: (context, estado) => const NotasVentaPagina(),
      ),
      GoRoute(
        path: CuentasPorCobrarPagina.ruta,
        builder: (context, estado) => const CuentasPorCobrarPagina(),
      ),
      GoRoute(
        path: CuentasPorPagarPagina.ruta,
        builder: (context, estado) => const CuentasPorPagarPagina(),
      ),
      GoRoute(
        path: MisCobrosPagina.ruta,
        builder: (context, estado) => const MisCobrosPagina(),
      ),
      GoRoute(
        path: ArqueoDiarioPagina.ruta,
        builder: (context, estado) => const ArqueoDiarioPagina(),
      ),
      GoRoute(
        path: MercadosPagina.ruta,
        builder: (context, estado) => const MercadosPagina(),
      ),
      GoRoute(
        path: RutasPagina.ruta,
        builder: (context, estado) => const RutasPagina(),
      ),

      for (final grupo in menuGrupos)
        for (final item in grupo.items)
          // Las que ya tienen pantalla propia se declaran arriba.
          if (item.ruta != ClientesPagina.ruta &&
              item.ruta != ProveedoresPagina.ruta &&
              item.ruta != ProductosPagina.ruta &&
              item.ruta != AlmacenesPagina.ruta &&
              item.ruta != StockPagina.ruta &&
              item.ruta != KardexPagina.ruta &&
              item.ruta != LotesPagina.ruta &&
              item.ruta != MetodosPagoPagina.ruta &&
              item.ruta != OrdenesCompraPagina.ruta &&
              item.ruta != MisComprasPagina.ruta &&
              item.ruta != RecepcionesPagina.ruta &&
              item.ruta != AjustesPagina.ruta &&
              item.ruta != TransferenciasPagina.ruta &&
              item.ruta != PrestamosPagina.ruta &&
              item.ruta != ConteosPagina.ruta &&
              item.ruta != ListasPreciosPagina.ruta &&
              item.ruta != AccesosPagina.ruta &&
              item.ruta != AuditoriaPagina.ruta &&
              item.ruta != PedidosPagina.ruta &&
              item.ruta != NotasVentaPagina.ruta &&
              item.ruta != CuentasPorCobrarPagina.ruta &&
              item.ruta != CuentasPorPagarPagina.ruta &&
              item.ruta != MisCobrosPagina.ruta &&
              item.ruta != ArqueoDiarioPagina.ruta &&
              item.ruta != MercadosPagina.ruta &&
              item.ruta != RutasPagina.ruta)
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
