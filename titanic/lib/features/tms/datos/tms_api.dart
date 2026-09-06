import '../../../core/red/cliente_api.dart';
import 'mercado.dart';

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
}
