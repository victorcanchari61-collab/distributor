import '../../../core/red/cliente_api.dart';
import 'sin_ventas_analisis_modelos.dart';

/// Llamadas de "Productos sin ventas": el análisis y los catálogos de sus
/// filtros (sucursal, categoría y marca).
class SinVentasAnalisisApi {
  const SinVentasAnalisisApi(this._api);

  final ClienteApi _api;

  /// GET /api/dashboard/sin-ventas/analisis
  Future<AnalisisSinVentas> analisis(ConsultaSinVentas consulta) async {
    final datos = await _api.get(
      '/dashboard/sin-ventas/analisis${consulta.query}',
    );
    return AnalisisSinVentas.desdeJson(
      datos is Map<String, dynamic> ? datos : const {},
    );
  }

  /// GET /api/almacen/opciones — los activos, para elegir uno.
  Future<List<OpcionCatalogo>> almacenes() async =>
      OpcionCatalogo.desdeLista(await _api.get('/almacen/opciones'));

  /// GET /api/categoria
  Future<List<OpcionCatalogo>> categorias() async =>
      OpcionCatalogo.desdeLista(await _api.get('/categoria'));

  /// GET /api/marca
  Future<List<OpcionCatalogo>> marcas() async =>
      OpcionCatalogo.desdeLista(await _api.get('/marca'));
}
