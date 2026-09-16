import '../../../core/red/cliente_api.dart';
import 'dms_modelos.dart';

/// Llamadas del módulo DMS: visitas y devoluciones.
class DmsApi {
  const DmsApi(this._api);

  final ClienteApi _api;

  static String _dia(DateTime f) =>
      '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

  /// Filtros que entiende el backend. Sin rango, el backend devuelve hoy.
  static String _consulta({
    DateTime? desde,
    DateTime? hasta,
    int? rutaId,
    int? vendedorId,
  }) {
    final partes = <String>[
      if (desde != null) 'desde=${_dia(desde)}',
      if (hasta != null) 'hasta=${_dia(hasta)}',
      if (rutaId != null) 'rutaId=$rutaId',
      if (vendedorId != null) 'vendedorId=$vendedorId',
    ];
    return partes.isEmpty ? '' : '?${partes.join('&')}';
  }

  // --- Visitas ---

  /// GET /api/visita
  Future<List<Visita>> visitas({
    DateTime? desde,
    DateTime? hasta,
    int? rutaId,
    int? vendedorId,
  }) async {
    final datos =
        await _api.get(
              '/visita${_consulta(desde: desde, hasta: hasta, rutaId: rutaId, vendedorId: vendedorId)}',
            )
            as List;
    return datos
        .map((e) => Visita.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/visita/resumen
  Future<ResumenVisitas> resumenVisitas({
    DateTime? desde,
    DateTime? hasta,
    int? rutaId,
    int? vendedorId,
  }) async => ResumenVisitas.desdeJson(
    await _api.get(
          '/visita/resumen${_consulta(desde: desde, hasta: hasta, rutaId: rutaId, vendedorId: vendedorId)}',
        )
        as Map<String, dynamic>,
  );

  // --- Devoluciones ---

  /// GET /api/devolucion
  Future<List<Devolucion>> devoluciones() async {
    final datos = await _api.get('/devolucion') as List;
    return datos
        .map((e) => Devolucion.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/devolucion/resumen
  Future<ResumenDevoluciones> resumenDevoluciones() async =>
      ResumenDevoluciones.desdeJson(
        await _api.get('/devolucion/resumen') as Map<String, dynamic>,
      );

  /// PATCH /api/devolucion/{id}/aprobar
  ///
  /// Recién aquí se mueve algo: entra el stock y la venta baja de importe, con
  /// lo que la deuda del cliente baja sola.
  Future<void> aprobar(int id) => _api.patch('/devolucion/$id/aprobar');

  /// PATCH /api/devolucion/{id}/rechazar
  Future<void> rechazar(int id, String motivo) =>
      _api.patch('/devolucion/$id/rechazar', cuerpo: {'motivo': motivo});
}
