import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/compras/estado/compras_controlador.dart';
import '../../features/dms/estado/dms_controlador.dart';
import '../../features/config/estado/config_controlador.dart';
import '../../features/facturacion/estado/facturacion_controlador.dart';
import '../../features/finanzas/estado/arqueo_controlador.dart';
import '../../features/finanzas/estado/finanzas_controlador.dart';
import '../../features/finanzas/estado/ganancia_controlador.dart';
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
  // gananciasProvider: el costo de lo vendido sale de los movimientos de stock.
  'stock': [
    stockProvider,
    stockDisponibleProvider,
    kardexProvider,
    lotesProvider,
    gananciasProvider,
  ],
  'kardex': [kardexProvider, stockProvider, stockDisponibleProvider],

  // --- Documentos ---
  // Un pedido nuevo tacha la visita de ese cliente.
  'pedidos': [
    pedidosProvider,
    stockDisponibleProvider,
    visitasProvider,
    resumenVisitasProvider,
  ],
  'notasventa': [
    notasVentaProvider,
    cuentasPorCobrarProvider,
    misCobrosProvider,
    gananciasProvider,
    stockProvider,
    kardexProvider,
  ],
  'devoluciones': [
    devolucionesProvider,
    notasVentaProvider,
    stockProvider,
    kardexProvider,
  ],
  'compras': [comprasProvider, cuentasPorPagarProvider],
  'ordenescompra': [ordenesCompraProvider, comprasProvider],
  'recepciones': [
    recepcionesProvider,
    comprasProvider,
    stockProvider,
    kardexProvider,
  ],
  'ajustes': [ajustesProvider, stockProvider, kardexProvider],
  'transferencias': [transferenciasProvider, stockProvider, kardexProvider],
  'prestamos': [prestamosProvider, stockProvider, kardexProvider],

  // --- Catálogos ---
  // El dia de visita y la ruta salen del cliente: cambiarlos rehace la lista.
  'clientes': [clientesProvider, visitasProvider, resumenVisitasProvider],
  'proveedores': [proveedoresProvider],
  // El selector del formulario de usuario sale de `opciones`, no del listado:
  // se invalidan los dos o el que acaban de dar de alta no se podria elegir
  // hasta salir y volver a entrar.
  'empleados': [empleadosProvider, empleadosOpcionesProvider, usuariosProvider],
  'categorias': [categoriasProvider, productosProvider],
  'marcas': [marcasProvider, productosProvider],
  'unidades': [unidadesProvider, productosProvider],
  'almacenes': [almacenesProvider, almacenesOpcionesProvider, stockProvider],
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
  // Enlazar una cuenta a una ficha cambia quien tiene usuario en Empleados, y
  // deja ocupada esa opcion para el resto.
  'usuarios': [usuariosProvider, empleadosProvider, empleadosOpcionesProvider],
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
