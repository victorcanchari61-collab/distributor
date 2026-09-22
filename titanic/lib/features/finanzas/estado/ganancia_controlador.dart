import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/consulta_tabla.dart';
import '../../auth/estado/auth_controlador.dart';
import '../datos/ganancia.dart';
import '../datos/ganancia_api.dart';

// --- Mis ganancias ---
//
// Es una consulta, no un catálogo: cada filtro cambia lo que se CALCULA (qué
// ventas entran en la suma), así que se le pide al servidor y no se recorta en
// el teléfono. Por eso lo que cambie un filtro vuelve a pedir, igual que el
// almacén en Stock.

final gananciaApiProvider = Provider(
  (ref) => GananciaApi(ref.watch(clienteApiProvider)),
);

/// Las ventas que entran en la suma. Null es "lo que va del mes": sin fechas
/// el servidor cuenta desde el día 1 hasta hoy.
final rangoGananciasProvider = StateProvider.autoDispose<DateTimeRange?>(
  (ref) => null,
);

/// La búsqueda ya asentada. La pantalla la pasa aquí cuando la persona deja de
/// teclear: cada letra pedida recalcularía todas las ganancias del rango.
final busquedaGananciasProvider = StateProvider.autoDispose((ref) => '');

/// Los filtros de lista. Null es "todos". Cada uno elige entre las opciones que
/// devuelve el servidor, nunca un texto libre.
final vendedorGananciasFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final categoriaGananciasFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final marcaGananciasFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final ventaGananciasFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final productoGananciasFiltroProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// Cuántos filtros de lista están puestos. El rango no cuenta: se ve siempre
/// en la cabecera de la pantalla.
final filtrosGananciasActivosProvider = Provider.autoDispose((ref) {
  var n = 0;
  if (ref.watch(vendedorGananciasFiltroProvider) != null) n++;
  if (ref.watch(categoriaGananciasFiltroProvider) != null) n++;
  if (ref.watch(marcaGananciasFiltroProvider) != null) n++;
  if (ref.watch(ventaGananciasFiltroProvider) != null) n++;
  if (ref.watch(productoGananciasFiltroProvider) != null) n++;
  return n;
});

/// Lo que los filtros puestos le piden al servidor. Los nombres de columna son
/// los que lee `GananciaService.Filtrar`.
final consultaGananciasProvider = Provider.autoDispose<ConsultaTabla>((ref) {
  final rango = ref.watch(rangoGananciasProvider);
  final columnas = {
    'vendedor': ref.watch(vendedorGananciasFiltroProvider),
    'categoria': ref.watch(categoriaGananciasFiltroProvider),
    'marca': ref.watch(marcaGananciasFiltroProvider),
    'venta': ref.watch(ventaGananciasFiltroProvider),
    'producto': ref.watch(productoGananciasFiltroProvider),
  };

  return ConsultaTabla(
    // El servidor corta cada tanda en 200.
    porPagina: 200,
    buscar: ref.watch(busquedaGananciasProvider),
    filtros: [
      if (rango != null) FiltroTabla.dias('fecha', rango.start, rango.end),
      for (final e in columnas.entries)
        if (e.value != null) FiltroTabla(columna: e.key, valor: e.value!),
    ],
  );
});

/// Cuántas tandas de productos se traen como máximo. Mil productos con ventas
/// en un rango ya no se leen en un teléfono: para eso están los filtros.
const _tandasMaximas = 5;

/// Los productos con su ganancia, los totales de TODO lo filtrado y las
/// opciones de los filtros.
///
/// El servidor corta en 200 por tanda: si hay más productos se piden las demás
/// hasta cubrirlos, con el tope de [_tandasMaximas]. Los totales y las opciones
/// vienen completos en cualquier tanda, así que no dependen de este corte.
final gananciasProvider = FutureProvider.autoDispose<GananciaPagina>((
  ref,
) async {
  final consulta = ref.watch(consultaGananciasProvider);
  final api = ref.watch(gananciaApiProvider);

  final primera = await api.listar(consulta);
  final items = [...primera.items];

  var tanda = 1;
  while (items.length < primera.total && tanda < _tandasMaximas) {
    tanda++;
    final siguiente = await api.listar(consulta.conPagina(tanda));
    // Una tanda vacía con el total sin cubrir: los datos cambiaron entre una
    // petición y otra. Se corta en vez de pedir para siempre.
    if (siguiente.items.isEmpty) break;
    items.addAll(siguiente.items);
  }

  return GananciaPagina(
    items: items,
    total: primera.total,
    resumen: primera.resumen,
    opciones: primera.opciones,
  );
});

/// Lo que hay para elegir en los filtros. Vacío mientras no llegue la primera
/// respuesta; después conserva la última aunque se esté recalculando, para que
/// las listas del panel de filtros no se vacíen cada vez que se elige una.
final opcionesGananciasProvider = Provider.autoDispose<GananciaOpciones>(
  (ref) =>
      ref.watch(gananciasProvider).valueOrNull?.opciones ??
      const GananciaOpciones(),
);
