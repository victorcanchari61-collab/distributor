import 'dart:convert';

import '../../../core/red/cliente_api.dart';
import 'novedad.dart';

/// Llamadas de las novedades de entrega y sus motivos.
class NovedadApi {
  const NovedadApi(this._api);

  final ClienteApi _api;

  // --- Motivos ---

  /// GET /api/motivonovedad. El catálogo completo, para quien lo administra.
  Future<List<MotivoNovedad>> motivos() async {
    final datos = await _api.get('/motivonovedad') as List;
    return datos
        .map((e) => MotivoNovedad.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/motivonovedad/opciones. Solo los activos, para elegir al entregar:
  /// lo pide quien convierte pedidos en venta, que no ve el catálogo.
  Future<List<MotivoNovedad>> opciones() async {
    final datos = await _api.get('/motivonovedad/opciones') as List;
    return datos
        .map((e) => MotivoNovedad.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/motivonovedad
  Future<MotivoNovedad> crearMotivo(Map<String, dynamic> cuerpo) async =>
      MotivoNovedad.desdeJson(
        await _api.post('/motivonovedad', cuerpo: cuerpo)
            as Map<String, dynamic>,
      );

  /// PUT /api/motivonovedad/{id}
  Future<MotivoNovedad> actualizarMotivo(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => MotivoNovedad.desdeJson(
    await _api.put('/motivonovedad/$id', cuerpo: cuerpo)
        as Map<String, dynamic>,
  );

  // --- Novedades ---

  /// POST /api/novedad/listar. Las últimas 200, ya ordenadas de la más nueva a
  /// la más vieja; el filtrado fino se hace en el teléfono, como en el resto.
  Future<List<Novedad>> novedades() async {
    final pagina =
        await _api.post(
              '/novedad/listar',
              cuerpo: {'pagina': 1, 'porPagina': 200},
            )
            as Map<String, dynamic>;
    return (pagina['items'] as List)
        .map((e) => Novedad.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/novedad/pdf. El reporte con lo mismo que muestra la pantalla.
  ///
  /// La búsqueda y los filtros viajan como el JSON de la consulta (la misma
  /// forma que recibe `/novedad/listar`) en un solo parámetro: son una lista de
  /// columna, operador y valor, y armar un parámetro por filtro sería tener que
  /// enseñarle al servidor cada uno. El servidor no pagina el papel: trae todo
  /// lo que pasa el filtro, hasta 2000 filas.
  Future<List<int>> pdf(Map<String, dynamic> consulta) => _api.archivo(
    '/novedad/pdf?consulta=${Uri.encodeComponent(jsonEncode(consulta))}',
  );

  /// GET /api/novedad/resumen
  Future<ResumenNovedades> resumen() async => ResumenNovedades.desdeJson(
    await _api.get('/novedad/resumen') as Map<String, dynamic>,
  );

  /// PATCH /api/novedad/{id}/verificar. El encargado cuenta lo que volvió.
  Future<Novedad> verificar(int id, Map<String, dynamic> cuerpo) async =>
      Novedad.desdeJson(
        await _api.patch('/novedad/$id/verificar', cuerpo: cuerpo)
            as Map<String, dynamic>,
      );

  /// PATCH /api/novedad/{id}/reabrir
  Future<Novedad> reabrir(int id) async => Novedad.desdeJson(
    await _api.patch('/novedad/$id/reabrir') as Map<String, dynamic>,
  );
}
