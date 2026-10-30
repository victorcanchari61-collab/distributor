import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/fechas.dart';
import '../../auth/estado/auth_controlador.dart';
import '../datos/crm.dart';
import '../datos/crm_api.dart';

final crmApiProvider = Provider((ref) => CrmApi(ref.watch(clienteApiProvider)));

/// El rango se manda como días; sin rango, el servidor mide del 1 de enero a hoy.
String? _desde(DateTimeRange? r) => r == null ? null : diaIso(r.start);
String? _hasta(DateTimeRange? r) => r == null ? null : diaIso(r.end);

// ------------------------------------------------------- Clientes con caída

/// El tramo que se mide: nulo es "del 1 de enero a hoy".
final rangoCaidaProvider = StateProvider.autoDispose<DateTimeRange?>(
  (ref) => null,
);

/// Una tarjeta tocada: deja solo los clientes de ese estado.
final estadoCaidaFiltroProvider = StateProvider.autoDispose<EstadoCaida?>(
  (ref) => null,
);

final busquedaCaidaProvider = StateProvider.autoDispose((ref) => '');
final vendedorCaidaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final mercadoCaidaFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// Los que dejaron de comprar: por cuántos días llevan sin hacerlo. Cada fila ya
/// trae sus días, así que se acota aquí y no en el servidor.
enum TramoInactividad {
  de16a30('16 a 30 días', 16, 30),
  de31a60('31 a 60 días', 31, 60),
  desde61('61 días o más', 61, null);

  const TramoInactividad(this.etiqueta, this.desde, this.hasta);

  final String etiqueta;
  final int desde;
  final int? hasta;

  bool incluye(int? dias) =>
      dias != null && dias >= desde && (hasta == null || dias <= hasta!);
}

final inactividadCaidaFiltroProvider =
    StateProvider.autoDispose<TramoInactividad?>((ref) => null);

final caidaProvider = FutureProvider.autoDispose<CaidaClientes>((ref) {
  final rango = ref.watch(rangoCaidaProvider);
  return ref
      .watch(crmApiProvider)
      .caida(
        desde: _desde(rango),
        hasta: _hasta(rango),
        estado: ref.watch(estadoCaidaFiltroProvider),
      );
});

/// Lo que se ve: el buscador y los filtros de vendedor y mercado se aplican
/// sobre lo ya traído, porque el servidor ya acotó por estado y tramo.
final caidaFiltradaProvider = Provider.autoDispose<List<FilaCaida>>((ref) {
  final todos =
      ref.watch(caidaProvider).valueOrNull?.items ?? const <FilaCaida>[];
  final texto = ref.watch(busquedaCaidaProvider).trim().toLowerCase();
  final vendedor = ref.watch(vendedorCaidaFiltroProvider);
  final mercado = ref.watch(mercadoCaidaFiltroProvider);
  final inactividad = ref.watch(inactividadCaidaFiltroProvider);

  return [
    for (final f in todos)
      if ((texto.isEmpty || f.buscable.contains(texto)) &&
          (vendedor == null || f.vendedor == vendedor) &&
          (mercado == null || f.mercado == mercado) &&
          (inactividad == null || inactividad.incluye(f.diasSinCompra)))
        f,
  ];
});

/// Qué dejó de comprar un cliente en el tramo que se mira.
final queDejoDeComprarProvider = FutureProvider.autoDispose
    .family<QueDejoDeComprar, int>((ref, clienteId) {
      final rango = ref.read(rangoCaidaProvider);
      return ref
          .watch(crmApiProvider)
          .queDejoDeComprar(
            clienteId,
            desde: _desde(rango),
            hasta: _hasta(rango),
          );
    });

// ------------------------------------------------------ Vendedores con caída

final rangoVendedoresProvider = StateProvider.autoDispose<DateTimeRange?>(
  (ref) => null,
);
final estadoVendedoresFiltroProvider = StateProvider.autoDispose<EstadoCaida?>(
  (ref) => null,
);
final busquedaVendedoresProvider = StateProvider.autoDispose((ref) => '');

final vendedoresCaidaProvider = FutureProvider.autoDispose<VendedoresCaida>((
  ref,
) {
  final rango = ref.watch(rangoVendedoresProvider);
  return ref
      .watch(crmApiProvider)
      .vendedores(desde: _desde(rango), hasta: _hasta(rango));
});

final vendedoresFiltradosProvider = Provider.autoDispose<List<FilaVendedor>>((
  ref,
) {
  final todos =
      ref.watch(vendedoresCaidaProvider).valueOrNull?.items ??
      const <FilaVendedor>[];
  final texto = ref.watch(busquedaVendedoresProvider).trim().toLowerCase();
  final estado = ref.watch(estadoVendedoresFiltroProvider);

  return [
    for (final f in todos)
      if ((texto.isEmpty || f.vendedor.toLowerCase().contains(texto)) &&
          (estado == null || f.estado == estado))
        f,
  ];
});

// ---------------------------------------------------- Productos sin ventas

/// Los atajos de días que ofrece el panel web.
const diasSinVentas = [7, 15, 30, 60, 90];

final diasSinVentasProvider = StateProvider.autoDispose((ref) => 30);
final busquedaSinVentasProvider = StateProvider.autoDispose((ref) => '');

/// con, sin o nulo (todos): solo los que tienen o no tienen stock.
final stockSinVentasFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final sinVentasProvider = FutureProvider.autoDispose<ProductosSinVentas>(
  (ref) =>
      ref.watch(crmApiProvider).sinVentas(ref.watch(diasSinVentasProvider)),
);

final sinVentasFiltradasProvider = Provider.autoDispose<List<ProductoSinVenta>>(
  (ref) {
    final todos =
        ref.watch(sinVentasProvider).valueOrNull?.items ??
        const <ProductoSinVenta>[];
    final texto = ref.watch(busquedaSinVentasProvider).trim().toLowerCase();
    final stock = ref.watch(stockSinVentasFiltroProvider);

    return [
      for (final p in todos)
        if ((texto.isEmpty || p.buscable.contains(texto)) &&
            (stock == null || (stock == 'con' ? p.stock > 0 : p.stock <= 0)))
          p,
    ];
  },
);

// --------------------------------------------------------- Mercados y rutas

final rangoZonasProvider = StateProvider.autoDispose<DateTimeRange?>(
  (ref) => null,
);

/// mercado o ruta.
final agruparZonasProvider = StateProvider.autoDispose((ref) => 'mercado');
final busquedaZonasProvider = StateProvider.autoDispose((ref) => '');

final zonasProvider = FutureProvider.autoDispose<ZonasCaida>((ref) {
  final rango = ref.watch(rangoZonasProvider);
  return ref
      .watch(crmApiProvider)
      .zonas(
        desde: _desde(rango),
        hasta: _hasta(rango),
        agrupar: ref.watch(agruparZonasProvider),
      );
});

final zonasFiltradasProvider = Provider.autoDispose<List<ZonaCaida>>((ref) {
  final todas =
      ref.watch(zonasProvider).valueOrNull?.items ?? const <ZonaCaida>[];
  final texto = ref.watch(busquedaZonasProvider).trim().toLowerCase();
  return [
    for (final z in todas)
      if (texto.isEmpty || z.nombre.toLowerCase().contains(texto)) z,
  ];
});

// ------------------------------------------------- Gestión y seguimiento

final catalogoSeguimientoProvider =
    FutureProvider.autoDispose<CatalogoSeguimiento>(
      (ref) => ref.watch(crmApiProvider).catalogo(),
    );

/// El texto que se escribe para buscar un cliente.
final busquedaClienteSeguimientoProvider = StateProvider.autoDispose(
  (ref) => '',
);

final clientesBuscadosProvider =
    FutureProvider.autoDispose<List<ClienteBuscado>>((ref) async {
      final texto = ref.watch(busquedaClienteSeguimientoProvider).trim();
      if (texto.length < 2) return const [];

      // Espera a que se deje de escribir: si se sigue tecleando, este proveedor
      // se descarta y la petición ni sale.
      var vigente = true;
      ref.onDispose(() => vigente = false);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!vigente) return const [];

      return ref.watch(crmApiProvider).buscar(texto);
    });

final fichaClienteProvider = FutureProvider.autoDispose
    .family<FichaCliente, int>(
      (ref, id) => ref.watch(crmApiProvider).ficha(id),
    );

final gestionesClienteProvider = FutureProvider.autoDispose
    .family<GestionesCliente, int>(
      (ref, id) => ref.watch(crmApiProvider).gestiones(id),
    );

final comprasClienteProvider = FutureProvider.autoDispose
    .family<ComprasCliente, int>(
      (ref, id) => ref.watch(crmApiProvider).compras(id),
    );

final documentosClienteProvider = FutureProvider.autoDispose
    .family<DocumentosCliente, int>(
      (ref, id) => ref.watch(crmApiProvider).documentos(id),
    );
