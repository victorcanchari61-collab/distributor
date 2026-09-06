import '../../../core/red/cliente_api.dart';
import 'mercado.dart';
import 'ruta.dart';

/// Llamadas del modulo TMS.
class TmsApi {
  const TmsApi(this._api);

  final ClienteApi _api;

  /// GET /api/mercado
  Future<List<Mercado>> mercados() async {
    final datos = await _api.get('/mercado') as List;
    return datos.map((e) => Mercado.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/mercado
  Future<Mercado> crearMercado(Map<String, dynamic> cuerpo) async => Mercado.desdeJson(
    await _api.post('/mercado', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PUT /api/mercado/{id}
  Future<Mercado> actualizarMercado(int id, Map<String, dynamic> cuerpo) async =>
      Mercado.desdeJson(
        await _api.put('/mercado/$id', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// DELETE /api/mercado/{id}. Solo Administrador.
  Future<void> eliminarMercado(int id) => _api.delete('/mercado/$id');

  /// GET /api/ruta
  Future<List<Ruta>> rutas() async {
    final datos = await _api.get('/ruta') as List;
    return datos.map((e) => Ruta.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/ruta
  Future<Ruta> crearRuta(Map<String, dynamic> cuerpo) async =>
      Ruta.desdeJson(await _api.post('/ruta', cuerpo: cuerpo) as Map<String, dynamic>);

  /// PUT /api/ruta/{id}
  Future<Ruta> actualizarRuta(int id, Map<String, dynamic> cuerpo) async =>
      Ruta.desdeJson(await _api.put('/ruta/$id', cuerpo: cuerpo) as Map<String, dynamic>);

  /// DELETE /api/ruta/{id}. Solo Administrador.
  Future<void> eliminarRuta(int id) => _api.delete('/ruta/$id');
}
