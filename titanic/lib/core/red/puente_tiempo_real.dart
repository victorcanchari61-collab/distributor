import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/compras/estado/compras_controlador.dart';
import '../../features/config/estado/config_controlador.dart';
import '../../features/facturacion/estado/facturacion_controlador.dart';
import '../../features/finanzas/estado/arqueo_controlador.dart';
import '../../features/finanzas/estado/finanzas_controlador.dart';
import '../../features/inventario/estado/inventario_controlador.dart';
import '../../features/maestros/estado/maestros_controlador.dart';
// Dos modulos declaran rutasProvider —el de clientes y el de reparto—: aqui se
// usa el de TMS con prefijo para no confundirlos.
import '../../features/tms/estado/tms_controlador.dart' as tms;
import '../../features/ventas/estado/ventas_controlador.dart';
import '../../features/alertas/estado/alertas_controlador.dart';
import '../permisos/permisos.dart';

/// Qué hay que volver a pedir cuando cambia cada módulo.
///
/// Está en un solo sitio y no repartido por las pantallas porque son treinta y
/// ocho: con una línea por pantalla, la mitad se habría quedado sin enganchar y
/// nadie lo notaría hasta que un vendedor cobrara con un precio viejo.
///
/// El nombre del módulo es el mismo que emite el backend en `AvisarAsync`, así
/// que agregar uno nuevo es agregar una fila aquí.
///
/// Se invalidan también los derivados que dependen de otro módulo: un precio
/// que cambia afecta a la lista de precios, y un movimiento de stock afecta al
/// kardex y a lo disponible para prometer.
final Map<String, List<ProviderOrFamily>> _providersPorModulo = {
  // --- Lo que un vendedor necesita al día mientras toma un pedido ---
  'productos': [productosProvider, stockProvider, stockDisponibleProvider],
  'listasprecio': [listasPrecioProvider, preciosListaActivaProvider],
  'stock': [stockProvider, stockDisponibleProvider, kardexProvider, lotesProvider],
  'kardex': [kardexProvider, stockProvider, stockDisponibleProvider],

  // --- Documentos ---
  'pedidos': [pedidosProvider, stockDisponibleProvider],
  'notasventa': [
    notasVentaProvider,
    cuentasPorCobrarProvider,
    misCobrosProvider,
    stockProvider,
    kardexProvider,
  ],
  'devoluciones': [notasVentaProvider, stockProvider, kardexProvider],
  'compras': [comprasProvider, cuentasPorPagarProvider],
  'ordenescompra': [ordenesCompraProvider, comprasProvider],
  'recepciones': [recepcionesProvider, comprasProvider, stockProvider, kardexProvider],
  'ajustes': [ajustesProvider, stockProvider, kardexProvider],
  'transferencias': [transferenciasProvider, stockProvider, kardexProvider],
  'prestamos': [prestamosProvider, stockProvider, kardexProvider],

  // --- Catálogos ---
  'clientes': [clientesProvider],
  'proveedores': [proveedoresProvider],
  'categorias': [categoriasProvider, productosProvider],
  'marcas': [marcasProvider, productosProvider],
  'unidades': [unidadesProvider, productosProvider],
  'almacenes': [almacenesProvider, stockProvider],
  'motivos': [motivosProvider, ajustesProvider],
  'metodospago': [metodosPagoProvider],
  'mercados': [tms.mercadosProvider, clientesProvider],
  'rutas': [tms.rutasProvider, rutasProvider, clientesProvider],
  'flota': [tms.vehiculosProvider, tms.resumenFlotaProvider],
  'conductores': [
    tms.conductoresProvider,
    tms.resumenConductoresProvider,
    tms.vehiculosProvider,
  ],
  'arqueo': [cuadresProvider, motivosGastoProvider],

  // Los datos de la empresa salen en la cabecera de cada papel: si cambian el
  // RUC o la direccion, lo que se imprima despues tiene que decir lo nuevo.
  'empresas': [empresasProvider],

  // --- Quién puede hacer qué ---
  // alertasProvider: un acceso pedido es una alerta mas para quien lo aprueba.
  // solicitudesProvider: alguien pide un permiso desde otro equipo y la
  // bandeja lo muestra sola; sin esto habria que salir y volver a entrar,
  // y quien espera al otro lado no sabe cuanto esperar.
  'permisos': [
    misPermisosProvider,
    usuariosProvider,
    rolesProvider,
    alertasProvider,
    solicitudesProvider,
  ],
  'roles': [misPermisosProvider, rolesProvider, usuariosProvider],
  'usuarios': [usuariosProvider],
};

/// Vuelve a pedir lo que ese módulo dejó viejo.
///
/// Invalidar y no recargar a mano: Riverpod vuelve a pedir solo lo que alguna
/// pantalla esté mirando, así que un cambio de compras no dispara llamadas si
/// nadie tiene compras abierto.
void refrescarPorCambio(WidgetRef ref, String modulo) {
  for (final provider in _providersPorModulo[modulo] ?? const []) {
    ref.invalidate(provider);
  }
}

/// Los módulos que el puente sabe refrescar.
Iterable<String> get modulosEscuchados => _providersPorModulo.keys;
